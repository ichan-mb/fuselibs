# Symbol Mapping

The Symbol Mapping feature in Fuse provides a comprehensive cross-platform mapping system between iOS SF Symbols and Android Material Design Icons. This allows developers to use consistent iconography across both platforms while maintaining native look and feel.

## Overview

The `SymbolMapping` class contains over 1,000 carefully curated symbol mappings organized into 30+ categories, ensuring that your app's icons look native on both iOS and Android platforms. Each mapping includes the iOS SF Symbol name, the corresponding Android Material Icon name, and information about fill variant availability.

## Basic Usage

### In UX Markup

```xml
<Image Symbol="heart" />
<Image Symbol="star.fill" />
<Image Symbol="house" />
```

## Symbol Categories

### Core Actions & Navigation
- **Common Actions**: `plus`, `minus`, `trash`, `edit`, `search`, `share`
- **Navigation**: `arrow.left`, `arrow.right`, `chevron.up`, `chevron.down`
- **Media Control**: `play`, `pause`, `stop`, `volume.up`, `volume.down`

### Communication & Social
- **Messaging**: `message`, `envelope`, `bubble.left`, `phone`
- **Social**: `person`, `person.2`, `heart`, `star`, `thumbsup`
- **Video Calling**: `video`, `facetime`, `shareplay`

### Status & Indicators
- **Alerts**: `info.circle`, `warning.triangle`, `error.circle`
- **Progress**: `checkmark`, `xmark`, `hourglass`, `timer`
- **Notifications**: `bell`, `bell.slash`, `flame`

### Business & Professional
- **Office**: `briefcase`, `folder`, `doc`, `signature`
- **Finance**: `dollarsign.circle`, `creditcard`, `chart.bar`
- **Legal**: `scale`, `building.columns`, `seal`

### Health & Medical
- **Healthcare**: `heart.text.square`, `cross.case`, `stethoscope`
- **Fitness**: `figure.run`, `dumbbell`, `figure.yoga`
- **Medical Equipment**: `pills`, `syringe`, `thermometer`

### Technology & Development
- **Devices**: `iphone`, `laptop`, `desktop`, `applewatch`
- **Connectivity**: `wifi`, `bluetooth`, `antenna`
- **Development**: `code`, `terminal`, `function`, `atom`

### Transportation & Travel
- **Vehicles**: `car`, `airplane`, `bicycle`, `train`
- **Travel**: `suitcase`, `map`, `location`, `compass`
- **Places**: `house`, `building`, `hotel`, `restaurant`

### Entertainment & Media
- **Gaming**: `gamecontroller`, `dice`, `trophy`
- **Music**: `music.note`, `guitar`, `speaker`
- **Photography**: `camera`, `photo`, `video`

### Weather & Environment
- **Weather**: `sun.max`, `cloud`, `rain`, `snow`
- **Environment**: `leaf`, `tree`, `drop`, `wind`
- **Climate**: `thermometer`, `humidity`, `hurricane`

### Shopping & Commerce
- **Shopping**: `cart`, `bag`, `basket`, `storefront`
- **Payment**: `creditcard`, `banknote`, `receipt`
- **Commerce**: `tag`, `percent`, `building.2`

### Home & Living
- **Furniture**: `sofa`, `chair`, `bed.double`
- **Appliances**: `refrigerator`, `oven`, `washer`
- **Home Systems**: `air.conditioner`, `heater`, `lightbulb`

### Sports & Recreation
- **Sports**: `football`, `basketball`, `tennis.racket`
- **Activities**: `figure.skiing`, `figure.swimming`, `bicycle`
- **Achievement**: `trophy`, `medal`, `crown`

### Education & Science
- **Education**: `book`, `graduationcap`, `studentdesk`
- **Science**: `atom`, `flask`, `microscope`
- **Mathematics**: `function`, `calculator`, `chart.pie`

### Security & Privacy
- **Security**: `lock`, `key`, `shield`, `eye`
- **Authentication**: `touchid`, `faceid`, `qrcode`
- **Privacy**: `hand.raised`, `eye.slash`, `lock.shield`

## Symbol Variants

### Fill Variants
Many symbols support fill variants for different visual styles:
```xml
<!-- Outline version -->
<Image Symbol="heart" />
<!-- Filled version -->
<Image Symbol="heart.fill" />
```

### Circle Variants
Some symbols include circle background variants:
```xml
<Image Symbol="info.circle" />
<Image Symbol="checkmark.circle" />
<Image Symbol="xmark.circle" />
```

### Badge Variants
Symbols with notification badges or indicators:
```xml
<Image Symbol="bell.badge" />
<Image Symbol="envelope.badge" />
<Image Symbol="cart.badge.plus" />
```

## Platform-Specific Behavior

### iOS (SF Symbols)
- Uses native iOS SF Symbol names
- Automatically adapts to system theme (light/dark)
- Supports dynamic type scaling
- Respects accessibility settings

### Android (Material Icons)
- Uses Material Design icon names
- Follows Material Design guidelines
- Consistent sizing across devices
- Supports theme variations

## Best Practices

### Choosing Symbols
1. **Use semantic names**: Choose symbols that represent the action or concept, not the visual appearance
2. **Consider context**: Ensure the symbol meaning is clear in your app's context
3. **Test both platforms**: Verify that both iOS and Android versions convey the intended meaning
4. **Use fill variants consistently**: Don't mix filled and outline versions randomly

### Accessibility
1. **Provide alt text**: Always include meaningful descriptions for screen readers
2. **Ensure contrast**: Verify adequate contrast ratios for visibility
3. **Size appropriately**: Use sufficient size for touch targets (minimum 44pt/44dp)

### Performance
1. **Prefer system symbols**: Use mapped symbols over custom images when possible
2. **Cache lookups**: Store frequently used symbol information to avoid repeated lookups
3. **Batch operations**: Group symbol operations when updating multiple icons

## Symbol Reference

### Complete Symbol List
The mapping includes over 1,000 symbols across these categories:

- **Actions** (60+ symbols): Basic user actions and operations
- **Navigation** (40+ symbols): Directional and navigation elements
- **Communication** (50+ symbols): Messaging, calling, and social features
- **Media** (45+ symbols): Audio, video, and entertainment controls
- **Status** (35+ symbols): Alerts, notifications, and indicators
- **Security** (25+ symbols): Privacy, authentication, and protection
- **Health** (30+ symbols): Medical, fitness, and wellness
- **Business** (40+ symbols): Professional and office functions
- **Technology** (55+ symbols): Devices, development, and connectivity
- **Transportation** (25+ symbols): Vehicles and travel
- **Weather** (20+ symbols): Climate and environmental conditions
- **Shopping** (20+ symbols): Commerce and retail
- **Home** (35+ symbols): Household and living
- **Sports** (25+ symbols): Recreation and athletics
- **Education** (30+ symbols): Learning and academic
- **International** (15+ symbols): Global and language features
- **And many more specialized categories...**

### Symbol Naming Convention
Symbols follow iOS SF Symbol naming conventions:
- Use lowercase letters and dots for separators: `arrow.left`, `person.circle`
- Fill variants end with `.fill`: `heart.fill`, `star.fill`
- Circle variants include `.circle`: `info.circle`, `plus.circle`
- Badge variants include `.badge`: `bell.badge`, `envelope.badge`

## Troubleshooting

### Common Issues

**Platform differences**
- Some symbols may look different between platforms while maintaining semantic meaning
- Always test on both iOS and Android devices
- Consider providing platform-specific alternatives if needed

**Performance concerns**
- Symbol lookup is fast (Dictionary O(1) access)
- Cache frequently used symbols if needed
- Avoid creating new mappings in performance-critical code

## Contributing

When adding new symbols to the mapping:

1. **Follow naming conventions**: Use iOS SF Symbol names as keys
2. **Verify Android equivalents**: Ensure Material Design icons convey the same meaning
3. **Set fill variant flag**: Indicate if the symbol supports fill variants
4. **Test both platforms**: Verify appearance on iOS and Android
5. **Update documentation**: Add new symbols to appropriate categories
6. **Consider accessibility**: Ensure symbols are accessible and clear

## Migration Guide

### From Custom Icons
If you're currently using custom icons, consider replacing them with system symbols:

**Before:**
```xml
<Image File="Assets/heart_icon.png" />
```

**After:**
```xml
<Image Symbol="heart" />
```

### From Platform-Specific Code
Replace platform-specific icon handling with unified symbols:

**Before:**
```csharp
if defined(iOS)
    iconName = "heart.fill";
else if defined(Android)
    iconName = "favorite";
```

**After:**
```csharp
var symbolInfo = SymbolMapping.All["heart"];
// Platform-specific name automatically resolved
```

## Examples

### Basic Button with Icon
```xml
<DockPanel>
    <Image Symbol="heart.fill" Color="#FF0000" Dock="Left" Margin="0,0,8,0" />
    <Text Value="Like" />
</DockPanel>
```

### Navigation Bar Icons
```xml
<Grid ColumnCount="5">
    <Image Symbol="house.fill" />
    <Image Symbol="magnifyingglass" />
    <Image Symbol="plus.circle" />
    <Image Symbol="heart" />
    <Image Symbol="person.circle" />
</Grid>
```

### Status Indicators
```xml
<StackPanel>
    <Image Symbol="checkmark.circle.fill" Color="#00AA00" />
    <Text Value="Success" />
</StackPanel>
```

### Media Player Controls
```xml
<Grid ColumnCount="5">
    <Image Symbol="backward.fill" />
    <Image Symbol="gobackward.15" />
    <Image Symbol="play.fill" />
    <Image Symbol="goforward.15" />
    <Image Symbol="forward.fill" />
</Grid>
```

## Resources

- [iOS SF Symbols Documentation](https://developer.apple.com/design/human-interface-guidelines/sf-symbols/)
- [Android Material Icons Documentation](https://fonts.google.com/icons)
- [Fuse Image Control Documentation](Image.md)
- [Accessibility Guidelines](../Accessibility.md)

---

*Last updated: January 2024*
*Symbol mapping contains 1,000+ cross-platform icon mappings*
