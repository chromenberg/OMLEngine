#+feature dynamic-literals
package ocss

import "shared:clay"

Layout_Aliases : map[string]string = {
  "direction"       = "layoutDirection",
  "gap"             = "childGap",
  "align-items"     = "childAlignment.x",
  "justify-content" = "childAlignment.y",
}

Style_Aliases : map[string]string = {
  "background-color" = "backgroundColor"
}

Alignment_X_Map : map[string]clay.LayoutAlignmentX = {
  "center" = clay.LayoutAlignmentX.Center,
  "left" = clay.LayoutAlignmentX.Left,
  "right" = clay.LayoutAlignmentX.Right,
}
Alignment_Y_Map : map[string]clay.LayoutAlignmentY = {
  "center" = clay.LayoutAlignmentY.Center,
  "top" = clay.LayoutAlignmentY.Top,
  "bottom" = clay.LayoutAlignmentY.Bottom,
}

