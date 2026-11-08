/** Keep a dropdown in the usable viewport without changing its anchor.
 * Positive numbers move right, negative numbers move left.
 * The caller is responsible for limiting the menu width to the viewport.
 */
export function dropdownViewportShift(rect,viewportWidth,gutter=12){
 const {left,right}=rect||{};
 if(![left,right,viewportWidth,gutter].every(Number.isFinite)||viewportWidth<=0)return 0;
 const safeGutter=Math.max(0,gutter);
 if(left<safeGutter)return Math.ceil(safeGutter-left);
 if(right>viewportWidth-safeGutter)return Math.floor(viewportWidth-safeGutter-right);
 return 0;
}
