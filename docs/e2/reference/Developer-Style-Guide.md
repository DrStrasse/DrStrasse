In general, just fix any lints that appear from glualint in your PR.

# ✍️ Formatting

## 🔤 Casing

* Constants should be in `SCREAMING_SNAKE_CASE`
* Locals should be in `camelCase` or *preferably* `snake_case`
* Globals should be in `PascalCase`
* Files should be in `snake_case.lua`

## ⚪ Whitespace

* Use tabs, not spaces
* Add space after commas, around operators and inside `{` curly braces `}` but not `(`parentheses`)` or `[`square brackets`]`
* Files should end with a newline

## ⚠️ Banned Features

* **DO NOT** use Garry's C-style aliases (`&&`, `||`, `!`, `!=`, `/* */`, `//`), they're not native to Lua and break most editors.

# 👨‍💻 Behavior

Code that goes into wire proper cannot favor specific addons not managed by the [@wiremod](https://github.com/wiremod) organization.  

Adding hooks/callbacks/interfaces to support external addons is fine.

[`wire-extras`](https://github.com/wiremod/wire-extras) is exempt from this.