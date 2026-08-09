Use this for reference when creating/reviewing an E2 addition. This list contains best practices for creating an E2 extension and will help simplify the review process.

## Extensions
- [ ] Used `registerExtension` to register the extension if it's optional OR defined the extension in `core/extloader.lua` if it's required
- [ ] Comes with sufficient test code that includes invalid use

## Types
- [ ] Default value (`argument 3`) is not `nil`
- [ ] Invalid function (`argument 7`) is sufficient for the type
- [ ] Comes with sufficient test code that includes invalid use

## E2 Functions
- [ ] E2 description defined
- [ ] All code paths return a proper value
  - Including early returns
- [ ] Uses `self:Throw` for improper usage
- [ ] Uses attributes whenever possible
- [ ] Assigned a fitting cost
- [ ] Comes with sufficient test code that includes invalid use

## Events
- [ ] Defined on [Events page](/wiremod/wire/wiki/Expression-2-Events#-list-of-events) after accepted
- [ ] Comes with sufficient test code that includes invalid use
