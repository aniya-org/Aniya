# Animations and Transitions Guide

This guide documents the animation and transition system implemented in the Aniya application.

## Overview

The Aniya app implements smooth animations and transitions across all screens to provide a polished user experience. The animation system includes:

1. **Page Transitions**: Smooth transitions between screens
2. **Loading Animations**: Animated loading indicators and skeleton screens
3. **UI Animations**: Subtle animations for UI elements

## Page Transitions

### Available Transition Types

The app supports multiple transition types defined in `TransitionType` enum:

- **Fade**: Simple fade in/out transition
- **Slide Right**: Slide from right to left
- **Slide Left**: Slide from left to right
- **Slide Up**: Slide from bottom to top
- **Slide Down**: Slide from top to bottom
- **Scale**: Scale with fade transition
- **Shared Axis**: Material Design shared axis transition
- **Rotation**: Rotation with fade transition

### Using Page Transitions

#### Method 1: Using AnimationUtils Extension

```dart
// Navigate with fade transition
await context.navigateFade(MyScreen());

// Navigate with slide right transition
await context.navigateSlideRight(MyScreen());

// Navigate with slide up transition
await context.navigateSlideUp(MyScreen());

// Navigate with scale transition
await context.navigateScale(MyScreen());

// Navigate with shared axis transition
await context.navigateSharedAxis(MyScreen());
```

#### Method 2: Using AnimationUtils Class

```dart
// Navigate with custom transition
await AnimationUtils.navigateWithCustom(
  context,
  MyScreen(),
  transitionsBuilder: AppPageTransitions.fadeTransition,
  duration: const Duration(milliseconds: 300),
);

// Replace screen with fade transition
await AnimationUtils.replaceWithFade(context, MyScreen());

// Replace screen with slide transition
await AnimationUtils.replaceWithSlide(context, MyScreen());
```

#### Method 3: Using CustomPageRoute Directly

```dart
Navigator.of(context).push(
  CustomPageRoute(
    builder: (_) => MyScreen(),
    transitionsBuilder: AppPageTransitions.slideFromRightTransition,
    transitionDuration: const Duration(milliseconds: 300),
  ),
);
```

## Loading Animations

### LoadingIndicator

The `LoadingIndicator` widget provides animated loading states with multiple styles:

```dart
// Circular loading indicator (default)
LoadingIndicator(
  message: 'Loading...',
  size: 48,
  type: LoadingIndicatorType.circular,
);

// Linear progress indicator
LoadingIndicator(
  message: 'Loading...',
  type: LoadingIndicatorType.linear,
);

// Animated dots indicator
LoadingIndicator(
  message: 'Loading...',
  type: LoadingIndicatorType.dots,
);

// Full screen loading
LoadingIndicator(
  message: 'Loading...',
  fullScreen: true,
);
```

### Skeleton Screens

Skeleton screens provide visual feedback while content is loading. They use shimmer animations to indicate loading state.

#### Available Skeleton Components

1. **ShimmerLoading**: Basic shimmer placeholder
   ```dart
   ShimmerLoading(
     width: 200,
     height: 100,
     borderRadius: BorderRadius.circular(8),
   )
   ```

2. **MediaSkeletonCard**: Skeleton for media items
   ```dart
   MediaSkeletonCard(
     width: double.infinity,
     height: 200,
   )
   ```

3. **SkeletonListItem**: Skeleton for list items
   ```dart
   SkeletonListItem(
     height: 80,
     borderRadius: BorderRadius.circular(12),
   )
   ```

4. **SkeletonGrid**: Grid of skeleton items
   ```dart
   SkeletonGrid(
     itemCount: 6,
     crossAxisCount: 2,
     childAspectRatio: 0.7,
   )
   ```

5. **SkeletonScreen**: Full skeleton screen
   ```dart
   SkeletonScreen(
     itemCount: 5,
     itemBuilder: (context, index) => SkeletonListItem(),
   )
   ```

### Implementing Skeleton Loading in Screens

Example from HomeScreen:

```dart
if (viewModel.isLoading && viewModel.trendingAnime.isEmpty) {
  return _buildSkeletonScreen(context, screenType);
}

Widget _buildSkeletonScreen(BuildContext context, ScreenType screenType) {
  final columnCount = ResponsiveLayoutManager.getGridColumns(
    MediaQuery.of(context).size.width,
  );

  return CustomScrollView(
    slivers: [
      SliverAppBar.large(
        title: const Text('Aniya'),
        floating: true,
      ),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
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

## Animation Utilities

The `AnimationUtils` class provides helper methods for creating common animations:

### Staggered List Animation

```dart
AnimatedList(
  initialItemCount: items.length,
  itemBuilder: (context, index, animation) {
    return AnimationUtils.buildStaggeredListItem(
      context: context,
      index: index,
      animation: animation,
      child: ListTile(title: Text(items[index])),
    );
  },
)
```

### Creating Custom Animations

```dart
// Bounce animation
final bounceAnimation = AnimationUtils.createBounceAnimation(controller);

// Fade animation
final fadeAnimation = AnimationUtils.createFadeAnimation(controller);

// Slide animation
final slideAnimation = AnimationUtils.createSlideAnimation(
  controller,
  begin: const Offset(0, 1),
  end: Offset.zero,
);

// Scale animation
final scaleAnimation = AnimationUtils.createScaleAnimation(
  controller,
  begin: 0.8,
  end: 1.0,
);
```

## Performance Considerations

### Transition Duration

All transitions use a standard duration of 300 milliseconds, which meets the requirement of completing transitions within 300ms as specified in Requirement 14.3.

### Optimization Tips

1. **Use Skeleton Screens**: Instead of showing a generic loading indicator, use skeleton screens that match the final layout. This provides better perceived performance.

2. **Lazy Load Content**: Load content in the background while showing skeleton screens.

3. **Avoid Excessive Animations**: Use animations purposefully to guide user attention, not as decoration.

4. **Test on Real Devices**: Always test animations on real devices to ensure smooth performance.

## Material Design 3 Compliance

All animations follow Material Design 3 guidelines:

- **Easing Curves**: Use `Curves.easeInOut` for smooth, natural motion
- **Duration**: 300ms for standard transitions
- **Staggering**: Stagger animations for list items to create visual hierarchy
- **Shared Axis**: Use shared axis transitions for related screens

## Screens with Animations

The following screens have been updated with smooth animations and skeleton loading:

1. **HomeScreen**: Skeleton grid loading for trending content
2. **MediaDetailsScreen**: Skeleton loading for media details
3. **SearchScreen**: Skeleton grid loading for search results
4. **LibraryScreen**: Skeleton grid loading for library items
5. **ExtensionScreen**: Skeleton list loading for extensions

## Future Enhancements

Potential improvements for animations:

1. **Gesture-based Animations**: Add swipe gestures for navigation
2. **Parallax Effects**: Add parallax scrolling for hero images
3. **Micro-interactions**: Add subtle animations for button presses
4. **Haptic Feedback**: Combine animations with haptic feedback
5. **Accessibility**: Ensure animations respect `prefers-reduced-motion` setting
