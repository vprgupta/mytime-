import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ModernNavbar extends StatefulWidget {
  final ScrollController? scrollController;
  const ModernNavbar({super.key, this.scrollController});

  @override
  State<ModernNavbar> createState() => _ModernNavbarState();
}

class _ModernNavbarState extends State<ModernNavbar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _rippleController;
  late AnimationController _hideController;
  late AnimationController _morphController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _hideAnimation;
  late Animation<double> _morphAnimation;
  late Animation<double> _blurAnimation;
  int _currentIndex = 0;
  int? _rippleIndex;
  bool _isVisible = true;
  double _lastScrollOffset = 0;
  bool _isExpanded = false;

  final List<NavItem> _navItems = [
    NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      route: '/',
      badgeCount: 0,
    ),
    NavItem(
      icon: Icons.book_outlined,
      activeIcon: Icons.book_rounded,
      label: 'Journal',
      route: '/thoughts',
      badgeCount: 0,
    ),
    NavItem(
      icon: Icons.apps_outlined,
      activeIcon: Icons.apps_rounded,
      label: 'Tools',
      route: '/tools',
      badgeCount: 0,
      subItems: [
        SubNavItem(icon: Icons.notifications_outlined, label: 'Reminders', route: '/reminders'),
        SubNavItem(icon: Icons.leaderboard_outlined, label: 'Leaderboard', route: '/leaderboard'),
      ],
    ),
    NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      route: '/profile',
      badgeCount: 0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _hideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _hideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hideController,
      curve: Curves.easeInOut,
    ));
    _morphAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _morphController,
      curve: Curves.elasticOut,
    ));
    _blurAnimation = Tween<double>(
      begin: 10.0,
      end: 25.0,
    ).animate(CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _hideController.forward();
    
    // Listen to scroll changes
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _animationController.dispose();
    _rippleController.dispose();
    _hideController.dispose();
    _morphController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (widget.scrollController == null) return;
    
    final currentOffset = widget.scrollController!.offset;
    final delta = currentOffset - _lastScrollOffset;
    
    // Auto-hide logic
    if (delta > 5 && _isVisible) {
      // Scrolling down - hide navbar
      setState(() => _isVisible = false);
      _hideController.reverse();
    } else if (delta < -5 && !_isVisible) {
      // Scrolling up - show navbar
      setState(() => _isVisible = true);
      _hideController.forward();
    }
    
    // Adaptive blur based on scroll speed
    final scrollSpeed = delta.abs();
    if (scrollSpeed > 10) {
      _morphController.forward();
    } else {
      _morphController.reverse();
    }
    
    _lastScrollOffset = currentOffset;
  }

  void _updateCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final newIndex = _navItems.indexWhere((item) => item.route == location);
    if (newIndex != -1 && newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateCurrentIndex(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _hideAnimation, _morphAnimation, _blurAnimation]),
      builder: (context, child) {
        final hideOffset = (1 - _hideAnimation.value) * 120;
        final morphScale = 1.0 + (_morphAnimation.value * 0.05);
        final minWidth = screenWidth * 0.7;
        final maxWidth = screenWidth * 0.9;
        final dynamicWidth = (maxWidth - (_morphAnimation.value * (maxWidth - minWidth))).clamp(minWidth, maxWidth);
        
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value + hideOffset),
          child: Container(
            margin: EdgeInsets.fromLTRB(
              (screenWidth - dynamicWidth) / 2,
              0,
              (screenWidth - dynamicWidth) / 2,
              bottomPadding + 20
            ),
            child: Transform.scale(
              scale: _scaleAnimation.value * morphScale,
              child: GestureDetector(
                onLongPress: () => _toggleExpanded(),
                onPanUpdate: (details) => _handlePanUpdate(details),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28 + (_morphAnimation.value * 8)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _blurAnimation.value,
                      sigmaY: _blurAnimation.value,
                    ),
                    child: Container(
                      height: 75 + (_isExpanded ? 20 : 0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha:0.2 + (_morphAnimation.value * 0.1)),
                            Colors.white.withValues(alpha:0.1 + (_morphAnimation.value * 0.05)),
                            Colors.white.withValues(alpha:0.15 + (_morphAnimation.value * 0.08)),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(28 + (_morphAnimation.value * 8)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha:0.3 + (_morphAnimation.value * 0.2)),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.1 + (_morphAnimation.value * 0.1)),
                            blurRadius: 30 + (_morphAnimation.value * 20),
                            offset: const Offset(0, -8),
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.05),
                            blurRadius: 15,
                            offset: const Offset(0, -4),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha:0.8),
                            blurRadius: 1,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Particle effects
                          if (_morphAnimation.value > 0.5)
                            ..._buildParticleEffects(),
                          
                          // Main navigation items
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8 + (_morphAnimation.value * 4),
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: _navItems.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                final isActive = index == _currentIndex;
                                
                                return _NavBarItem(
                                  item: item,
                                  isActive: isActive,
                                  rippleAnimation: _rippleIndex == index ? _rippleController : null,
                                  onTap: () => _onItemTapped(context, index, item.route),
                                  morphValue: _morphAnimation.value,
                                );
                              }).toList(),
                            ),
                          ),
                          
                          // Enhanced active indicator
                          _buildDynamicActiveIndicator(),
                          
                          // Quick actions (when expanded)
                          if (_isExpanded)
                            _buildQuickActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  List<Widget> _buildParticleEffects() {
    return List.generate(3, (index) {
      return Positioned(
        left: 20.0 + (index * 60),
        top: 10 + (index * 5),
        child: AnimatedBuilder(
          animation: _morphController,
          builder: (context, child) {
            return Transform.scale(
              scale: _morphAnimation.value,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.6 * _morphAnimation.value),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      );
    });
  }
  
  void _toggleExpanded() {
    HapticFeedback.mediumImpact();
    setState(() => _isExpanded = !_isExpanded);
  }
  
  void _handlePanUpdate(DragUpdateDetails details) {
    // Magnetic snap to edges
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth * 0.1) {
      // Snap to left
      HapticFeedback.selectionClick();
    } else if (details.globalPosition.dx > screenWidth * 0.9) {
      // Snap to right
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildDynamicActiveIndicator() {
    final screenWidth = MediaQuery.of(context).size.width;
    final dynamicWidth = screenWidth * (0.9 - (_morphAnimation.value * 0.1));
    final itemWidth = (dynamicWidth - 32) / 4;
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      left: (_currentIndex * itemWidth) + 16,
      top: 6,
      child: AnimatedBuilder(
        animation: _morphAnimation,
        builder: (context, child) {
          return Container(
            width: itemWidth - 16,
            height: 60 + (_morphAnimation.value * 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF667eea).withValues(alpha:0.3 + (_morphAnimation.value * 0.2)),
                  const Color(0xFF764ba2).withValues(alpha:0.2 + (_morphAnimation.value * 0.1)),
                  const Color(0xFF667eea).withValues(alpha:0.25 + (_morphAnimation.value * 0.15)),
                ],
              ),
              borderRadius: BorderRadius.circular(20 + (_morphAnimation.value * 8)),
              border: Border.all(
                color: Colors.white.withValues(alpha:0.4 + (_morphAnimation.value * 0.3)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withValues(alpha:0.3 + (_morphAnimation.value * 0.2)),
                  blurRadius: 12 + (_morphAnimation.value * 8),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Positioned(
      top: -40,
      left: 20,
      right: 20,
      child: Container(
        height: 35,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha:0.2),
              Colors.white.withValues(alpha:0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha:0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickAction(Icons.add_task, () => context.push('/add-task')),
            _buildQuickAction(Icons.timer, () => context.push('/timer')),
            _buildQuickAction(Icons.settings, () => context.push('/settings')),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index, String route) {
    HapticFeedback.selectionClick();
    
    if (index != _currentIndex) {
      setState(() {
        _rippleIndex = index;
        _currentIndex = index;
      });
      
      _rippleController.forward().then((_) {
        _rippleController.reset();
        setState(() => _rippleIndex = null);
      });
      
      // Enhanced navigation with page transitions
      if (route == '/') {
        context.go(route);
      } else if (route == '/tools') {
        _showToolsMenu(context);
      } else {
        context.push(route);
      }
    }
  }

  void _showToolsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha:0.3),
                  Colors.white.withValues(alpha:0.2),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: Colors.white.withValues(alpha:0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    _buildToolItem(context, Icons.notifications_rounded, 'Reminders', '/reminders'),
                    _buildToolItem(context, Icons.leaderboard_rounded, 'Leaderboard', '/leaderboard'),
                    _buildToolItem(context, Icons.schedule_rounded, 'Schedule', '/schedule'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolItem(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF007AFF)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final AnimationController? rippleAnimation;
  final double morphValue;

  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.rippleAnimation,
    this.morphValue = 0.0,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _bounceController;
  late Animation<double> _iconAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _iconAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: widget.rippleAnimation ?? _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
        _bounceController.forward().then((_) => _bounceController.reverse());
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dynamicIconSize = 28.0 + (widget.morphValue * 4);
    final dynamicPadding = 12.0 + (widget.morphValue * 4);
    
    return GestureDetector(
      onTapDown: (_) => _bounceController.forward(),
      onTapUp: (_) => _bounceController.reverse(),
      onTapCancel: () => _bounceController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _bounceAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dynamicPadding, vertical: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Enhanced ripple effect
              if (widget.rippleAnimation != null)
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF667eea).withValues(alpha:0.3 * (1 - _rippleAnimation.value)),
                              const Color(0xFF764ba2).withValues(alpha:0.1 * (1 - _rippleAnimation.value)),
                            ],
                          ),
                        ),
                        transform: Matrix4.identity()
                          // ignore: deprecated_member_use
                          ..scale(1 + _rippleAnimation.value * 0.8, 1 + _rippleAnimation.value * 0.8, 1.0),
                      ),
                    );
                  },
                ),
              
              // Main content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ScaleTransition(
                        scale: widget.isActive ? _iconAnimation : 
                               const AlwaysStoppedAnimation(1.0),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: RotationTransition(
                                turns: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            key: ValueKey(widget.isActive),
                            padding: EdgeInsets.all(widget.isActive ? 4 : 0),
                            decoration: widget.isActive ? BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha:0.2),
                                  Colors.white.withValues(alpha:0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ) : null,
                            child: Icon(
                              widget.isActive ? widget.item.activeIcon : widget.item.icon,
                              size: dynamicIconSize,
                              color: widget.isActive 
                                  ? Colors.white
                                  : Colors.white.withValues(alpha:0.6),
                            ),
                          ),
                        ),
                      ),
                      
                      // Enhanced badge with glow
                      if (widget.item.badgeCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFff416c), Color(0xFFff4b2b)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha:0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              widget.item.badgeCount > 99 ? '99+' : '${widget.item.badgeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 11 + (widget.morphValue * 1),
                      fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                      color: widget.isActive 
                          ? Colors.white
                          : Colors.white.withValues(alpha:0.7),
                      letterSpacing: widget.isActive ? 0.5 : 0,
                    ),
                    child: Text(
                      widget.item.label,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final int badgeCount;
  final List<SubNavItem>? subItems;

  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.badgeCount = 0,
    this.subItems,
  });
}

class SubNavItem {
  final IconData icon;
  final String label;
  final String route;

  SubNavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}