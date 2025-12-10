package com.example.mytime

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class CommitmentModeManager(private val context: Context) {
    
    private val prefs: SharedPreferences = context.getSharedPreferences("CommitmentMode", Context.MODE_PRIVATE)
    private val keyAlias = "CommitmentModeKey"
    private val TAG = "CommitmentModeManager"
    
    companion object {
        private const val KEY_COMMITMENT_END_TIME = "commitment_end_time"
        private const val KEY_COMMITMENT_DEVICE_ID = "commitment_device_id"
        private const val KEY_COMMITMENT_ENCRYPTED_BACKUP = "commitment_encrypted_backup"
        private const val EXTERNAL_BACKUP_FILE = "commitment_backup.enc"
    }
    
    init {
        initializeKeyStore()
        recoverFromBackupIfNeeded()
    }
    
    /**
     * Initialize Android Keystore for encryption
     */
    private fun initializeKeyStore() {
        try {
            val keyStore = KeyStore.getInstance("AndroidKeyStore")
            keyStore.load(null)
            
            if (!keyStore.containsAlias(keyAlias)) {
                val keyGenerator = KeyGenerator.getInstance(
                    KeyProperties.KEY_ALGORITHM_AES,
                    "AndroidKeyStore"
                )
                
                val keyGenParameterSpec = KeyGenParameterSpec.Builder(
                    keyAlias,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(false)
                    .build()
                
                keyGenerator.init(keyGenParameterSpec)
                keyGenerator.generateKey()
                Log.d(TAG, "Keystore initialized successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize keystore", e)
        }
    }
    
    /**
     * Get device unique identifier
     */
    private fun getDeviceId(): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: Build.SERIAL
        } catch (e: Exception) {
            "UNKNOWN_DEVICE"
        }
    }
    
    /**
     * Start commitment mode with given duration in hours
     * Special case: hours = 0 means 5 minutes (for testing)
     */
    fun startCommitment(hours: Int): Boolean {
        try {
            // Special case: hours = 0 means 5 minutes for testing
            val durationMillis = if (hours == 0) {
                5 * 60 * 1000L  // 5 minutes
            } else {
                hours * 60 * 60 * 1000L  // Normal: hours to milliseconds
            }
            
            val endTime = System.currentTimeMillis() + durationMillis
            val deviceId = getDeviceId()
            
            // Save to SharedPreferences
            prefs.edit().apply {
                putLong(KEY_COMMITMENT_END_TIME, endTime)
                putString(KEY_COMMITMENT_DEVICE_ID, deviceId)
                apply()
            }
            
            // Create encrypted backup
            createEncryptedBackup(endTime, deviceId)
            
            // Also save to legacy location for compatibility
            context.getSharedPreferences("MyTaskPrefs", Context.MODE_PRIVATE)
                .edit()
                .putLong("uninstall_lock_end_time", endTime)
                .apply()
            
            // CRITICAL: Immediately block uninstallation of MyTime itself using Device Admin
            enableUninstallProtection()
            
            val durationText = if (hours == 0) "5 minutes" else "$hours hours"
            Log.d(TAG, "Commitment started for $durationText, ends at $endTime")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start commitment", e)
            return false
        }
    }
    
    /**
     * CRITICAL: Enable Device Admin uninstall protection for MyTime itself
     * This prevents uninstallation during commitment mode
     */
    private fun enableUninstallProtection() {
        try {
            val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            val adminComponent = ComponentName(context, AppProtectionDeviceAdminReceiver::class.java)
            
            if (devicePolicyManager != null && devicePolicyManager.isAdminActive(adminComponent)) {
                // Block uninstallation of MyTime itself
                devicePolicyManager.setUninstallBlocked(adminComponent, context.packageName, true)
                Log.d(TAG, "🔒 ENABLED uninstall protection for MyTime")
            } else {
                Log.w(TAG, "⚠️ Device Admin NOT active - cannot enable uninstall protection!")
                Log.w(TAG, "User must enable Device Admin first for full protection")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to enable uninstall protection", e)
        }
    }
    
    /**
     * Check if commitment mode is currently active
     */
    fun isCommitmentActive(): Boolean {
        val endTime = getCommitmentEndTime()
        return endTime > System.currentTimeMillis()
    }
    
    /**
     * Get commitment end time
     */
    fun getCommitmentEndTime(): Long {
        return prefs.getLong(KEY_COMMITMENT_END_TIME, 0L)
    }
    
    /**
     * Get remaining commitment duration in milliseconds
     */
    fun getRemainingTime(): Long {
        val endTime = getCommitmentEndTime()
        val remaining = endTime - System.currentTimeMillis()
        return if (remaining > 0) remaining else 0
    }
    
    /**
     * Validate that commitment hasn't been tampered with
     */
    fun validateCommitment(): Boolean {
        val savedDeviceId = prefs.getString(KEY_COMMITMENT_DEVICE_ID, null)
        val currentDeviceId = getDeviceId()
        
        if (savedDeviceId != null && savedDeviceId != currentDeviceId) {
            Log.w(TAG, "Device ID mismatch - possible tampering detected")
            return false
        }
        
        return true
    }
    
    /**
     * Create encrypted backup of commitment state
     */
    private fun createEncryptedBackup(endTime: Long, deviceId: String) {
        try {
            val data = "$endTime|$deviceId"
            val encrypted = encrypt(data)
            
            // Save to internal storage first
            prefs.edit().putString(KEY_COMMITMENT_ENCRYPTED_BACKUP, encrypted).apply()
            
            // Try to save to external cache as well (survives app data clear in some cases)
            try {
                val backupFile = File(context.externalCacheDir, EXTERNAL_BACKUP_FILE)
                backupFile.writeText(encrypted)
                Log.d(TAG, "External backup created at ${backupFile.absolutePath}")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to create external backup (non-critical)", e)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create encrypted backup", e)
        }
    }
    
    /**
     * Recover commitment state from backup if main storage was cleared
     */
    private fun recoverFromBackupIfNeeded() {
        try {
            val currentEndTime = prefs.getLong(KEY_COMMITMENT_END_TIME, 0L)
            
            // If no active commitment in main storage, check backups
            if (currentEndTime == 0L || currentEndTime < System.currentTimeMillis()) {
                // Try internal backup first
                var encrypted = prefs.getString(KEY_COMMITMENT_ENCRYPTED_BACKUP, null)
                
                // Try external backup if internal is missing
                if (encrypted == null) {
                    try {
                        val backupFile = File(context.externalCacheDir, EXTERNAL_BACKUP_FILE)
                        if (backupFile.exists()) {
                            encrypted = backupFile.readText()
                            Log.d(TAG, "Found external backup")
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to read external backup", e)
                    }
                }
                
                // Decrypt and restore if backup found
                if (encrypted != null) {
                    val decrypted = decrypt(encrypted)
                    val parts = decrypted.split("|")
                    if (parts.size == 2) {
                        val endTime = parts[0].toLongOrNull() ?: 0L
                        val deviceId = parts[1]
                        
                        // Only restore if still valid and device matches
                        if (endTime > System.currentTimeMillis() && deviceId == getDeviceId()) {
                            prefs.edit().apply {
                                putLong(KEY_COMMITMENT_END_TIME, endTime)
                                putString(KEY_COMMITMENT_DEVICE_ID, deviceId)
                                apply()
                            }
                            Log.d(TAG, "Commitment restored from backup! Remaining: ${(endTime - System.currentTimeMillis()) / 1000}s")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to recover from backup", e)
        }
    }
    
    /**
     * Encrypt data using Android Keystore
     */
    private fun encrypt(data: String): String {
        try {
            val keyStore = KeyStore.getInstance("AndroidKeyStore")
            keyStore.load(null)
            val secretKey = keyStore.getKey(keyAlias, null) as SecretKey
            
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            
            val iv = cipher.iv
            val encrypted = cipher.doFinal(data.toByteArray(Charsets.UTF_8))
            
            // Prepend IV to encrypted data
            val combined = iv + encrypted
            return Base64.encodeToString(combined, Base64.DEFAULT)
        } catch (e: Exception) {
            Log.e(TAG, "Encryption failed", e)
            throw e
        }
    }
    
    /**
     * Decrypt data using Android Keystore
     */
    private fun decrypt(encryptedData: String): String {
        try {
            val keyStore = KeyStore.getInstance("AndroidKeyStore")
            keyStore.load(null)
            val secretKey = keyStore.getKey(keyAlias, null) as SecretKey
            
            val combined = Base64.decode(encryptedData, Base64.DEFAULT)
            
            // Extract IV (first 12 bytes for GCM)
            val iv = combined.copyOfRange(0, 12)
            val encrypted = combined.copyOfRange(12, combined.size)
            
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val spec = GCMParameterSpec(128, iv)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
            
            val decrypted = cipher.doFinal(encrypted)
            return String(decrypted, Charsets.UTF_8)
        } catch (e: Exception) {
            Log.e(TAG, "Decryption failed", e)
            throw e
        }
    }
    
    /**
     * Clear commitment (only if expired)
     */
    fun clearIfExpired() {
        if (!isCommitmentActive() && getCommitmentEndTime() > 0) {
            prefs.edit().clear().apply()
            
            // Clear legacy location
            context.getSharedPreferences("MyTaskPrefs", Context.MODE_PRIVATE)
                .edit()
                .remove("uninstall_lock_end_time")
                .apply()
            
            // Clear external backup
            try {
                val backupFile = File(context.externalCacheDir, EXTERNAL_BACKUP_FILE)
                if (backupFile.exists()) {
                    backupFile.delete()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to delete external backup", e)
            }
            
            // CRITICAL: Disable Device Admin protections
            disableProtections()
            
            Log.d(TAG, "✅ Commitment cleared (expired) - Protections disabled")
        }
    }
    
    /**
     * Disable all protection mechanisms (Device Admin, services, etc.)
     * Called when commitment expires to allow app uninstallation
     */
    private fun disableProtections() {
        try {
            // Get DevicePolicyManager and admin component
            val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            val adminComponent = ComponentName(context, AppProtectionDeviceAdminReceiver::class.java)
            
            // Only proceed if DevicePolicyManager exists and admin is active
            if (devicePolicyManager != null && devicePolicyManager.isAdminActive(adminComponent)) {
                Log.d(TAG, "🔓 Removing Device Admin protections...")
                
                // Step 1: Remove uninstall block for this app
                try {
                    devicePolicyManager.setUninstallBlocked(adminComponent, context.packageName, false)
                    Log.d(TAG, "✅ Uninstall block removed")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to remove uninstall block: ${e.message}")
                }
                
                // Step 2: Remove Device Admin (allows user to uninstall)
                try {
                    devicePolicyManager.removeActiveAdmin(adminComponent)
                    Log.d(TAG, "✅ Device Admin removed")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to remove Device Admin: ${e.message}")
                }
            } else {
                Log.d(TAG, "Device Admin not active, no removal needed")
            }
            
            // Step 3: Stop all protection services
            stopProtectionServices()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disable protections", e)
        }
    }
    
    /**
     * Stop all protection services
     */
    private fun stopProtectionServices() {
        try {
            // Stop CommitmentMonitoringService
            try {
                val serviceIntent = Intent(context, CommitmentMonitoringService::class.java)
                context.stopService(serviceIntent)
                Log.d(TAG, "✅ Stopped CommitmentMonitoringService")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to stop CommitmentMonitoringService: ${e.message}")
            }
            
            // Stop UninstallProtectionService
            try {
                val uninstallProtectionIntent = Intent(context, UninstallProtectionService::class.java)
                context.stopService(uninstallProtectionIntent)
                Log.d(TAG, "✅ Stopped UninstallProtectionService")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to stop UninstallProtectionService: ${e.message}")
            }
            
            // Stop BypassDetectionService
            try {
                val bypassDetectionIntent = Intent(context, BypassDetectionService::class.java)
                context.stopService(bypassDetectionIntent)
                Log.d(TAG, "✅ Stopped BypassDetectionService")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to stop BypassDetectionService: ${e.message}")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping protection services", e)
        }
    }
}
