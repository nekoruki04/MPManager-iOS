# MP Manager — Native iOS UI/UX Replication Specification

## 1. Visual Identity & Color Palette

Replicating MT Manager / MP Manager authentic Material 3 and Dark palette:

| Element | Hex Color | Role in Interface |
|---|---|---|
| **Primary Accent** | `#2196F3` / `#1E88E5` | Active pane border, primary buttons, highlighted text |
| **Secondary Accent** | `#4CAF50` | Second pane highlight, success states, verified APK badges |
| **Background Dark** | `#121212` / `#1E1E1E` | Main dual-pane background, list view background |
| **Surface Dark** | `#242424` / `#2D2D2D` | Top bar, bottom bar, bottom drawer, dialogs |
| **Surface Variant** | `#383838` | Hover/press highlight, table borders, dividers |
| **Folder Amber** | `#FFA000` | Folder icons |
| **Archive Purple** | `#9C27B0` | ZIP, 7Z, TAR, RAR, APK archive icons |
| **Binary / Code Teal** | `#009688` | DEX, SO, Mach-O, ELF, SH scripts |
| **Image Green** | `#4CAF50` | PNG, JPG, GIF, WebP image icons |
| **Text Blue** | `#2196F3` | TXT, XML, JSON, Plist, Log file icons |

---

## 2. Layout & Responsive Geometry

### iPad Pro 11-inch (2018, A12X, 2388 × 1668 at 264 ppi)
- **Primary Layout:** Permanent side-by-side dual-pane view.
- **Split Ratio:** 50% / 50% split with a 2 pt draggable divider.
- **Pane Highlight:** 2 pt solid border around active pane.
- **Navigation Drawer:** Left modal slide-over drawer (320 pt width) or collapsible sidebar.
- **Bottom Bar:** Centered navigation bar with 5 icons: Back (44×44), Forward (44×44), Add/New (44×44), Sync (44×44), Up (44×44).

### iPhone 11 Pro (A13, 2436 × 1125 at 458 ppi)
- **Adaptive Layout:** Swipeable dual-pane or toggleable dual-pane header tab (Pane 1 / Pane 2) with instant synchronization and cross-pane drag/drop support.
- **Compact Toolbar:** Top bar path display with auto-marquee or middle-truncation.

---

## 3. Key Interaction Flows
1. **Tap on File:**
   - Folder / Archive: Enters directory or browses archive contents in place without extracting.
   - APK: Opens comprehensive APK Info Dialog (Package Name, Version, Signatures, Dex List, Components).
   - Text / Code / Plist: Opens built-in Text Editor with line numbers and Find & Replace.
   - Database (.db / .sqlite): Opens SQLite Browser.
   - Binary / Executable: Opens Hex Editor or Mach-O / ELF Inspector.
   - Media: Opens QuickLook / built-in media preview.
2. **Long-Press on Item:**
   - Triggers MT Manager-style contextual menu:
     - Copy, Move, Rename, Delete, Chmod (Permissions), Properties, Add to ZIP, Compare.
3. **Bottom Drawer (Bookmarks & History):**
   - Swiping up on the bottom bar opens the drawer with two tabs: Bookmarks and Navigation History.
4. **Copy / Move Across Panes:**
   - Selecting files in active pane $\rightarrow$ Tap Copy/Move in menu $\rightarrow$ Target automatically defaults to inactive pane's current directory $\rightarrow$ Shows progress HUD.
