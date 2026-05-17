# AI Coder Instruction Manual: Design Standards & Global Requirements

## 1. System Context & Purpose
This document outlines global ecosystem requirements and design specifications that apply universally across all projects—regardless of language (Python, Android, Web/Docker). AI coders must enforce these standards when generating new applications, components, or UI interfaces.

## 2. Strict Constraints & Operational Rules
When modifying or creating code within this ecosystem, AI must adhere strictly to the following constraints:
- **READ-ONLY Mode Acknowledgment:** You must not alter existing CSS or configuration files without explicit user instruction.
- **Mandatory Dark Mode:** All projects featuring a visible UI element (web pages, mobile views, desktop interfaces) *must* include a dark mode option.
- **Data Safety Requirement:** All projects must include a method or script to back up configurations, `.env` files, and databases.

## 3. Robust Dark Mode Design Specification
When implementing Dark Mode for a web or UI project, AI must strictly use the "Robust Dark Mode" standard. This specification goes beyond simple color inversion, focusing on OLED smearing prevention, accessibility, and visual hierarchy.

### 3.1. Foundational Colors
- **Never use Pure Black (`#000000`):** It causes "smearing" on OLED screens and creates high-contrast blurring around text.
- **Use Standard Dark Grey (`#121212`):** Set the base background color (`--bg-body`) to `#121212`. This allows shadows and elevations to be rendered accurately.

### 3.2. Typography & Contrast
- **Opacity over Solid Hex Colors:** Do not use dark grey hex codes for text on top of various surface levels. Instead, use pure white with reduced opacity to blend naturally.
  - *High Emphasis Text:* `rgba(255, 255, 255, 0.87)`
  - *Medium Emphasis Text:* `rgba(255, 255, 255, 0.60)`
  - *Disabled Text:* `rgba(255, 255, 255, 0.38)`
- **Avoid Pure White Text (`#FFFFFF`):** At 100% opacity on a dark background, pure white is visually vibrating and causes eye strain.

### 3.3. Color Desaturation
- **Desaturate Accents:** Standard brand colors (e.g., Deep Blue `#0055ff`) often vibrate and fail WCAG contrast checks against dark backgrounds.
- **Implementation:** Lighten and desaturate accent colors (e.g., change to Pastel Blue `#8ab4f8`) when toggling dark mode.

### 3.4. Visual Hierarchy (Elevation)
- **Depth via Elevation:** Shadows are not visible against a dark void. Depth must be indicated by lightness. The closer a UI element is to the user, the lighter its grey background must be.
  - *Background (Level 0):* `#121212`
  - *Cards/Containers (Level 1):* `#1e1e1e`
  - *Modals/Dropdowns (Level 2):* `#2d2d2d`

## 4. Implementation Guidelines
- **CSS Custom Properties:** Utilize CSS variables (`:root` and `[data-theme="dark"]`) to manage the system.
- **FOUC Prevention:** Implement a blocking, inline Javascript execution script in the `<head>` of HTML documents to check local storage (`localStorage.getItem('theme')`) or system preference (`window.matchMedia('(prefers-color-scheme: dark)')`) *before* the DOM paints, preventing a "Flash of Unstyled Content" (FOUC).
- **Image Handling:** Apply a CSS filter to images in dark mode to reduce glare (e.g., `filter: brightness(0.8) contrast(1.2);`).
