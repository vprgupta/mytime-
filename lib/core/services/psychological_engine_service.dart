import 'dart:math';

class PsychologicalEngineService {
  static final PsychologicalEngineService _instance = PsychologicalEngineService._internal();
  factory PsychologicalEngineService() => _instance;
  PsychologicalEngineService._internal();

  // FEAR ENGINE - Loss Aversion & Sunk Cost
  Map<String, dynamic> getStreakDeathTimer(int currentStreak, bool hasActiveTask) {
    if (currentStreak == 0) return {'message': '', 'urgency': 0, 'color': 'grey'};
    
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final timeLeft = endOfDay.difference(now);
    
    final hours = timeLeft.inHours;
    final minutes = timeLeft.inMinutes % 60;
    
    String urgencyMessage;
    String color;
    int urgencyLevel;
    
    if (hours < 2) {
      urgencyMessage = '🚨 STREAK DEATH IN ${hours}h ${minutes}m! $currentStreak DAYS AT RISK!';
      color = 'critical';
      urgencyLevel = 5;
    } else if (hours < 4) {
      urgencyMessage = '⚠️ $currentStreak-day streak expires in ${hours}h ${minutes}m!';
      color = 'danger';
      urgencyLevel = 4;
    } else if (hours < 8) {
      urgencyMessage = '⏰ Protect your $currentStreak-day streak! ${hours}h ${minutes}m left';
      color = 'warning';
      urgencyLevel = 3;
    } else {
      urgencyMessage = '🔥 $currentStreak-day streak active - don\'t break the chain!';
      color = 'normal';
      urgencyLevel = 2;
    }
    
    return {
      'message': urgencyMessage,
      'urgency': urgencyLevel,
      'color': color,
      'hoursLeft': hours,
      'minutesLeft': minutes,
    };
  }

  Map<String, dynamic> getOpportunityCostCalculator(int currentStreak, int wastedMinutes) {
    final compoundLoss = _calculateCompoundLoss(currentStreak, wastedMinutes);
    final futureRegret = _getFutureRegretMessage(currentStreak, wastedMinutes);
    
    return {
      'wastedTime': wastedMinutes,
      'compoundLoss': compoundLoss,
      'futureRegret': futureRegret,
      'streakValue': _calculateStreakValue(currentStreak),
      'lossMultiplier': _getLossMultiplier(currentStreak),
    };
  }

  int _calculateCompoundLoss(int streak, int wastedMinutes) {
    // Psychological amplification: each wasted minute costs more with higher streaks
    final multiplier = (streak / 10).clamp(1.0, 5.0);
    return (wastedMinutes * multiplier * 3).round(); // 3x compound effect
  }

  String _getFutureRegretMessage(int streak, int wastedMinutes) {
    if (streak >= 30) {
      return 'In 1 year: "I had a $streak-day streak and threw it away for $wastedMinutes minutes"';
    } else if (streak >= 7) {
      return 'Tomorrow: "I wasted my $streak-day momentum for $wastedMinutes minutes"';
    } else {
      return 'Tonight: "I could have built momentum but wasted $wastedMinutes minutes"';
    }
  }

  int _calculateStreakValue(int streak) {
    // Exponential value increase to create loss aversion
    return (streak * streak * 10).clamp(0, 10000);
  }

  double _getLossMultiplier(int streak) {
    return (1 + (streak / 10)).clamp(1.0, 10.0);
  }

  // SOCIAL PRESSURE ENGINE
  Map<String, dynamic> getAnonymousRanking(int currentStreak, int completedTasks) {
    final fakeRankings = _generateFakeRankings(currentStreak, completedTasks);
    final userRank = _calculateUserRank(currentStreak, completedTasks);
    
    return {
      'userRank': userRank,
      'totalUsers': 1000 + Random().nextInt(500), // Fake user base
      'rankings': fakeRankings,
      'percentile': _calculatePercentile(userRank),
      'shameMessage': _getShameMessage(userRank),
      'prideMessage': _getPrideMessage(userRank),
    };
  }

  List<Map<String, dynamic>> _generateFakeRankings(int userStreak, int userTasks) {
    final rankings = <Map<String, dynamic>>[];
    final random = Random();
    
    // Generate fake users around user's performance
    for (int i = 1; i <= 10; i++) {
      final variance = random.nextInt(20) - 10; // ±10 variation
      rankings.add({
        'rank': i,
        'streak': (userStreak + variance).clamp(0, 365),
        'tasks': (userTasks + random.nextInt(10) - 5).clamp(0, 50),
        'username': 'User${1000 + random.nextInt(9000)}',
      });
    }
    
    return rankings;
  }

  int _calculateUserRank(int streak, int tasks) {
    // Fake ranking based on performance
    final score = (streak * 10) + (tasks * 2);
    if (score > 500) return Random().nextInt(50) + 1; // Top 50
    if (score > 200) return Random().nextInt(200) + 51; // Top 250
    if (score > 100) return Random().nextInt(300) + 251; // Top 550
    return Random().nextInt(450) + 551; // Bottom half
  }

  int _calculatePercentile(int rank) {
    return ((1000 - rank) / 1000 * 100).round();
  }

  String _getShameMessage(int rank) {
    if (rank > 800) return '😞 Bottom 20% - Others are crushing their goals while you struggle';
    if (rank > 600) return '😐 Below average - 60% of users are more consistent than you';
    if (rank > 400) return '🤔 Middle of the pack - Half the users are beating you';
    return '';
  }

  String _getPrideMessage(int rank) {
    if (rank <= 50) return '🏆 TOP 5%! You\'re crushing it - don\'t lose this status!';
    if (rank <= 100) return '⭐ TOP 10%! You\'re in the elite group - maintain your edge!';
    if (rank <= 200) return '🔥 TOP 20%! You\'re ahead of most - keep the momentum!';
    return '';
  }

  // VARIABLE REWARD ENGINE - Dopamine Hijacking
  Map<String, dynamic> getVariableReward(int completedTasks, int currentStreak) {
    final random = Random();
    final shouldTrigger = random.nextDouble() < _getRewardProbability(completedTasks);
    
    if (!shouldTrigger) return {'hasReward': false};
    
    final rewardType = _selectRewardType(currentStreak);
    final reward = _generateReward(rewardType, currentStreak);
    
    return {
      'hasReward': true,
      'type': rewardType,
      'title': reward['title'],
      'message': reward['message'],
      'value': reward['value'],
      'rarity': reward['rarity'],
    };
  }

  double _getRewardProbability(int completedTasks) {
    // Variable ratio schedule - most addictive
    if (completedTasks % 7 == 0) return 0.8; // High chance every 7th task
    if (completedTasks % 3 == 0) return 0.3; // Medium chance every 3rd
    return 0.1; // Low baseline chance
  }

  String _selectRewardType(int streak) {
    final random = Random();
    final weights = <String, double>{
      'streak_multiplier': 0.3,
      'productivity_lottery': 0.25,
      'achievement_unlock': 0.2,
      'power_boost': 0.15,
      'rare_badge': 0.1,
    };
    
    double totalWeight = weights.values.reduce((a, b) => a + b);
    double randomValue = random.nextDouble() * totalWeight;
    
    for (final entry in weights.entries) {
      randomValue -= entry.value;
      if (randomValue <= 0) return entry.key;
    }
    
    return 'streak_multiplier';
  }

  Map<String, dynamic> _generateReward(String type, int streak) {
    final random = Random();
    
    switch (type) {
      case 'streak_multiplier':
        final multiplier = 1.5 + (random.nextDouble() * 2); // 1.5x to 3.5x
        return {
          'title': '🚀 STREAK MULTIPLIER!',
          'message': 'Your next ${multiplier.toStringAsFixed(1)}x streak bonus is ACTIVE!',
          'value': multiplier,
          'rarity': 'common',
        };
        
      case 'productivity_lottery':
        final prize = ['Extra Break Time', 'Streak Shield', 'Double XP', 'Time Bonus'][random.nextInt(4)];
        return {
          'title': '🎰 PRODUCTIVITY LOTTERY WIN!',
          'message': 'You won: $prize! Keep going for more chances!',
          'value': prize,
          'rarity': 'uncommon',
        };
        
      case 'achievement_unlock':
        final achievements = ['Consistency Master', 'Time Warrior', 'Focus Champion', 'Streak Legend'];
        final achievement = achievements[random.nextInt(achievements.length)];
        return {
          'title': '🏅 ACHIEVEMENT UNLOCKED!',
          'message': '$achievement badge earned! Share your success!',
          'value': achievement,
          'rarity': 'rare',
        };
        
      case 'power_boost':
        return {
          'title': '⚡ POWER BOOST ACTIVATED!',
          'message': 'Next 3 tasks give 2x progress! Use it wisely!',
          'value': '2x Progress',
          'rarity': 'uncommon',
        };
        
      case 'rare_badge':
        final badges = ['Diamond Streak', 'Platinum Focus', 'Elite Performer', 'Legendary Discipline'];
        final badge = badges[random.nextInt(badges.length)];
        return {
          'title': '💎 RARE BADGE EARNED!',
          'message': '$badge - Only top 1% earn this! You\'re special!',
          'value': badge,
          'rarity': 'legendary',
        };
        
      default:
        return {
          'title': '🎉 SURPRISE BONUS!',
          'message': 'Keep going - more surprises await!',
          'value': 'Bonus',
          'rarity': 'common',
        };
    }
  }

  // COMMITMENT ESCALATION
  Map<String, dynamic> getCommitmentContract(int currentStreak) {
    final stakes = _calculateStakes(currentStreak);
    final consequences = _getConsequences(currentStreak);
    
    return {
      'stakes': stakes,
      'consequences': consequences,
      'contractText': _generateContractText(currentStreak, stakes),
      'escalationLevel': _getEscalationLevel(currentStreak),
    };
  }

  Map<String, dynamic> _calculateStakes(int streak) {
    if (streak >= 30) {
      return {
        'level': 'high',
        'description': 'Your 30+ day reputation is at stake',
        'value': 'Elite Status',
      };
    } else if (streak >= 7) {
      return {
        'level': 'medium',
        'description': 'Your weekly momentum is at risk',
        'value': 'Consistency Badge',
      };
    } else {
      return {
        'level': 'low',
        'description': 'Your fresh start opportunity',
        'value': 'New Beginning',
      };
    }
  }

  List<String> _getConsequences(int streak) {
    if (streak >= 30) {
      return [
        'Lose your elite status among top performers',
        'Start over from day 1 like a beginner',
        'Disappoint everyone who looks up to you',
        'Prove you can\'t handle long-term commitment',
      ];
    } else if (streak >= 7) {
      return [
        'Waste a full week of progress',
        'Join the 90% who give up',
        'Reset to zero like everyone else',
        'Prove you\'re not ready for success',
      ];
    } else {
      return [
        'Stay in the cycle of starting over',
        'Remain average like most people',
        'Never build real momentum',
        'Keep making excuses forever',
      ];
    }
  }

  String _generateContractText(int streak, Map<String, dynamic> stakes) {
    return '''
🔒 COMMITMENT CONTRACT

I, the user, commit to maintaining my $streak-day streak.

STAKES: ${stakes['description']}
VALUE AT RISK: ${stakes['value']}

If I break this streak, I acknowledge:
• I will lose all progress and start from day 1
• I will join the majority who quit
• I will prove I lack discipline
• I will disappoint my future self

SIGNED: ${DateTime.now().toString().split(' ')[0]}
''';
  }

  int _getEscalationLevel(int streak) {
    if (streak >= 50) return 5; // Maximum pressure
    if (streak >= 30) return 4; // High pressure
    if (streak >= 14) return 3; // Medium pressure
    if (streak >= 7) return 2;  // Low pressure
    return 1; // Minimal pressure
  }
}