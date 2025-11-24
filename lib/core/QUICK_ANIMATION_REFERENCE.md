# Quick Animation Reference

## Quick Start

### Navigate with Animation
```dart
// Fade transition
await context.navigateFade(MyScreen());

// Slide from right
await context.navigateSlideRight(MyScreen());

// Slide from bottom
await context.navigateSlideUp(MyScreen());

// Scale transition
await context.navigateScale(MyScreen());

// Shared axis (Material Design)
await context.navigateSharedAxis(MyScreen());
```

### Show Loading State
```dart
// Circular loading
LoadingIndicator(message: 'Loading...');

// Linear progress
LoadingIndicator(
  message: 'Loading...',
  type: LoadingIndicatorType.linear,
);

// Animated dots
LoadingIndicator(
  message: 'Loading...',
  type: LoadingIndicatorType.dots,
);
```

### Show Skeleton Screen
```dart
// Single shimmer placeholder
ShimmerLoading(width: 200, height: 100);

// Media card skeleton
MediaSkeletonCard();

// List item skeleton
SkeletonListItem(height: 80);

// Grid of skeletons
SkeletonGrid(itemCount: 6, crossAxisCount: 2);
```

## Common Patterns

### Implement Skeleton Loading in Screen
```dart
if (viewModel.isLoading && viewModel.items.isEmpty) {
  return _buildSkeletonScreen(context);
}

Widget _buildSkeletonScreen(BuildContext context) {
  return CustomScrollView(
    slivers: [
      SliverAppBar.large(title: const Text('Title')),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const MediaSkeletonCard(),
            childCount: 6,
          ),
        ),
      ),
    ],
  );
}
```

### Create Custom Animation
```dart
class MyAnimatedWidget extends StatefulWidget {
  @override
  State<MyAnimatedWidget> createState() => _MyAnimatedWidgetState();
}

class _MyAnimatedWidgetState extends State<MyAnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = AnimationUtils.createFadeAnimation(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: MyContent());
  }
}
```

## Animation Types

| Type | Duration | Use Case |
|------|----------|----------|
| Fade | 300ms | Simple screen transitions |
| Slide Right | 300ms | Forward navigation |
| Slide Left | 300ms | Back navigation |
| Slide Up | 300ms | Modal/bottom sheet |
| Slide Down | 300ms | Dismiss modal |
| Scale | 300ms | Detail view entry |
| Shared Axis | 300ms | Related screens |
| Rotation | 300ms | Special transitions |

## Loading Indicator Types

| Type | Best For |
|------|----------|
| Circular | General loading |
| Linear | Progress indication |
| Dots | Subtle loading |

## Skeleton Components

| Component | Use Case |
|-----------|----------|
| ShimmerLoading | Generic placeholder |
| MediaSkeletonCard | Media grid items |
| SkeletonListItem | List items |
| SkeletonGrid | Grid layouts |
| SkeletonScreen | Full screen loading |

## Performance Tips

1. **Use Skeleton Screens**: Better perceived performance than generic loaders
2. **Keep Animations Short**: 300ms is the standard duration
3. **Use Easing Curves**: `Curves.easeInOut` for natural motion
4. **Test on Real Devices**: Ensure smooth 60fps performance
5. **Avoid Excessive Animations**: Use purposefully, not as decoration

## Accessibility

- All animations use standard Material Design 3 curves
- Animations respect system animation settings
- Loading states are clearly indicated
- Transitions don't interfere with navigation

## Common Issues

**Animation Jank?**
- Check if animation is running on main thread
- Reduce animation complexity
- Test on real device (not emulator)

**Skeleton Not Matching Layout?**
- Ensure skeleton dimensions match final content
- Use same grid/list structure
- Test responsive layouts

**Transition Too Fast/Slow?**
- Standard duration is 300ms
- Adjust `transitionDuration` parameter if needed
- Keep consistent across app

## Resources

- Full guide: `lib/core/ANIMATIONS_GUIDE.md`
- Implementation: `lib/core/navigation/page_transitions.dart`
- Utilities: `lib/core/utils/animation_utils.dart`
- Widgets: `lib/core/widgets/skeleton_screen.dart`
