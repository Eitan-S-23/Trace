# Dialplate 仪表盘布局调整指南

本文档说明当前仪表盘页各 UI 元素在哪里调整，以及调整后如何验证。

## 坐标规则

仪表盘屏幕为 `240 x 320`，坐标原点在左上角：

```text
x 向右增大
y 向下增大
```

大部分元素在 `DialplateView::Create()` 中创建，位置通常是下面两种写法：

```cpp
OverlayLabel(root, FONT("xxx"), color, x, y, text);
Value_Create(root, FONT("xxx"), color, LV_ALIGN_TOP_LEFT, x, y, init);
```

需要移动元素时，优先只改 `x, y`。需要调整大小时，改 `FONT("...")` 使用的字体名。

## 核心文件

`USER/App/Pages/Dialplate/DialplateView.cpp`

负责创建所有可见对象、设置坐标、字体、颜色、图标和动态布局。

`USER/App/Pages/Dialplate/DialplateView.h`

负责声明 UI 对象指针和对外更新接口，例如 `SetAltitude()`、`SetBattery()`、`SetTurnDirection()`。

`USER/App/Pages/Dialplate/Dialplate.cpp`

负责把模型数据刷新到 View，例如速度、海拔、电量、GPS 卫星数、转向状态。

`USER/App/Pages/Dialplate/DialplateModel.cpp`

负责订阅和拉取数据源，例如 `GPS`、`Power`、`SportStatus`。

`.claude/skin_new_240.png`

仪表盘底图，包含地图、路线、面板边框等静态装饰。

`.claude/fix_dialplate_skin.py`

用于修复并重新生成底图资源 `img_src_dialplate_skin.c`。

## 顶部中间 320m 和转向

位置在 `DialplateView::Create()` 中这几行：

```cpp
ui.nav.labelDist = Value_Create(root, FONT("bahnschrift_24"), COL_WHITE, LV_ALIGN_TOP_LEFT, 99, 10, "320");
lv_obj_align_to(ui.nav.labelDistUnit, ui.nav.labelDist, LV_ALIGN_OUT_RIGHT_BOTTOM, 3, -3);
ui.nav.labelTurnIcon = OverlayLabel(root, FONT("iconfont_20"), COL_GREEN, 73, 8, ICON_TURN_RIGHT);
ui.nav.labelTurnText = OverlayLabel(root, FONT("cn_16"), COL_GREEN, 104, 23, TXT_TURN_RIGHT);
```

`320` 数字位置：

改 `Value_Create(..., 99, 10, "320")` 里的 `99, 10`。

`m` 单位位置：

改 `lv_obj_align_to(..., 3, -3)` 里的偏移量。第一个数是横向偏移，第二个数是纵向偏移。

转向图标位置：

改 `OverlayLabel(..., 73, 8, ICON_TURN_RIGHT)` 里的 `73, 8`。

中文“直行/左转/右转”位置：

改 `OverlayLabel(..., 104, 23, TXT_TURN_RIGHT)` 里的 `104, 23`。

转向显示内容在 `DialplateView::SetTurnDirection()` 中切换：

```cpp
void DialplateView::SetTurnDirection(TurnDirection_t dir)
```

如果只想调整位置，不需要改 `SetTurnDirection()`。

## 左上角状态区

GPS 图标和卫星数：

```cpp
ui.status.imgGps = OverlayImg(root, "satellite", COL_GREEN, 7, 12);
ui.status.labelGpsSat = Value_Create(root, FONT("bahnschrift_13"), COL_WHITE, LV_ALIGN_TOP_LEFT, 25, 11, "0");
```

蓝牙图标：

```cpp
ui.status.imgBt = OverlayImg(root, "bluetooth", COL_GRAY, 7, 28);
```

心率图标和数值：

```cpp
OverlayLabel(root, FONT("iconfont_20"), COL_REC_RED, 4, 45, ICON_HEART_RATE);
ui.status.labelHr = Value_Create(root, FONT("bahnschrift_13"), COL_WHITE, LV_ALIGN_TOP_LEFT, 24, 52, "145");
```

如果图标和文字重叠，优先移动文字的 `x`，再移动图标。

## 右上角电量和坡度

电池图标和电量数字：

```cpp
ui.status.imgBattery = OverlayImg(root, "battery", COL_BLUE, 201, 7);
ui.status.labelBattery = Value_Create(root, FONT("bahnschrift_13"), COL_WHITE, LV_ALIGN_TOP_LEFT, 212, 8, "100");
```

实际刷新逻辑在：

```cpp
void DialplateView::SetBattery(uint8_t usage, bool charging)
```

`SetBattery()` 中这行控制电量数字相对电池图标的位置：

```cpp
lv_obj_align_to(ui.status.labelBattery, ui.status.imgBattery, LV_ALIGN_OUT_RIGHT_MID, 3, -1);
```

第一个偏移 `3` 控制数字离图标的水平距离，第二个偏移 `-1` 控制上下位置。

坡度文字：

```cpp
ui.status.labelSlope = Value_Create(root, FONT("bahnschrift_13"), COL_GREEN, LV_ALIGN_TOP_RIGHT, -9, 30, "3.2%");
```

因为使用 `LV_ALIGN_TOP_RIGHT`，`x` 是相对右边缘的偏移。更靠左就把 `-9` 改得更小，例如 `-15`。

## 海拔显示

海拔现在是动态布局，由图标、数字、单位 `m` 三部分组成。

创建位置：

```cpp
ui.status.labelAlt = Value_Create(root, FONT("bahnschrift_13"), COL_WHITE, LV_ALIGN_TOP_LEFT, 198, 61, "532");
ui.status.labelAltUnit = OverlayLabel(root, FONT("bahnschrift_13"), COL_GRAY, 226, 61, "m");
ui.status.labelAltIcon = OverlayLabel(root, FONT("iconfont_20"), COL_BLUE, 181, 56, ICON_ALTITUDE);
```

最终位置由 `SetAltitude()` 重新计算：

```cpp
void DialplateView::SetAltitude(int altitude)
```

关键参数：

```cpp
const lv_coord_t unitRight = 235;
const lv_coord_t unitGap = 2;
const lv_coord_t iconGap = 3;
```

`unitRight` 控制 `m` 的右边界位置。

`unitGap` 控制数字和 `m` 的距离。

`iconGap` 控制海拔图标和数字的距离。

如果海拔整体太靠右或太靠左，改 `unitRight`。如果只是间距不舒服，改 `unitGap` 或 `iconGap`。

## 速度和动态字号

速度数值位置和字号逻辑在 `Dialplate.cpp`：

```cpp
static void SetSpeedLabel(lv_obj_t* label, float speed)
```

默认字号和位置：

```cpp
const char* fontName = "bahnschrift_48";
lv_coord_t y = 91;
```

大于等于 `10.0` 或文本较长时使用：

```cpp
fontName = "bahnschrift_32";
y = 102;
```

大于等于 `100.0` 或更长时使用：

```cpp
fontName = "bahnschrift_24";
y = 108;
```

如果速度仍然超框，优先调小字体，再微调 `lv_obj_align(label, LV_ALIGN_TOP_LEFT, 10, y)` 里的 `10` 和 `y`。

## 右侧 AVG/TIME/TRIP/CAL

四个右侧指标数值位置在 `DialplateView::Create()`：

```cpp
const lv_coord_t my[METRIC_NUM] = { 93, 138, 183, 226 };
Value_Create(root, FONT(mft[i]), mcl[i], LV_ALIGN_TOP_MID, 204 - SCR_CX, my[i], miv[i]);
```

`my` 数组依次对应：

```text
AVG
TIME
TRIP
CAL
```

横向中心由 `204 - SCR_CX` 控制。右移就增大 `204`，左移就减小 `204`。

CAL 动态字号逻辑在 `Dialplate.cpp`：

```cpp
static void SetCalorieLabel(lv_obj_t* label, int calorie)
```

超过 `10000` 或文本过长时会切到 `bahnschrift_13`。

## 地图标签 SPRING / BRIDGE

位置在 `DialplateView::Create()`：

```cpp
Value_Create(root, FONT("bahnschrift_13"), COL_WHITE, LV_ALIGN_TOP_LEFT, 126, 73, "SPRING");
Value_Create(root, FONT("bahnschrift_13"), COL_GRAY, LV_ALIGN_TOP_LEFT, 126, 85, "1.2km");
Value_Create(root, FONT("bahnschrift_13"), COL_WHITE, LV_ALIGN_TOP_LEFT, 62, 155, "BRIDGE");
Value_Create(root, FONT("bahnschrift_13"), COL_GRAY, LV_ALIGN_TOP_LEFT, 62, 167, "2.4km");
```

如果移动地点名，距离文字也要一起移动，通常保持 `y` 相差 `12`。

## 底部按钮

按钮点击区域：

```cpp
ui.btnCont.btnMap  = Btn_Create(root, 8,   286, 72, 30);
ui.btnCont.btnRec  = Btn_Create(root, 86,  286, 68, 30);
ui.btnCont.btnMenu = Btn_Create(root, 160, 286, 72, 30);
```

地图按钮内容：

```cpp
OverlayLabel(ui.btnCont.btnMap, FONT("iconfont_20"), COL_CYAN, 12, 5, ICON_MAP);
OverlayLabel(ui.btnCont.btnMap, FONT("cn_16"), COL_CYAN, 32, 6, TXT_MAP);
```

菜单按钮内容：

```cpp
OverlayLabel(ui.btnCont.btnMenu, FONT("iconfont_20"), COL_BLUE, 12, 5, ICON_MENU);
OverlayLabel(ui.btnCont.btnMenu, FONT("cn_16"), COL_BLUE, 32, 6, TXT_MENU);
```

REC 内容由 `recContent` 居中控制：

```cpp
lv_obj_set_size(ui.btnCont.recContent, 38, 14);
lv_obj_center(ui.btnCont.recContent);
```

如果地图或菜单选中后显示不全，优先调整按钮内容的 `x`，例如把 `32` 改成 `28`。

## 皮肤底图和边框

顶部中间边框、地图、右侧面板、底部按钮外框属于底图：

```text
.claude/skin_new_240.png
USER/App/Resource/Image/img_src_dialplate_skin.c
```

不要用 LVGL 重新画顶部中间边框。正确做法是保留底图边框，只用 LVGL 叠加动态文字。

如果底图需要重新修复或重新生成，执行：

```powershell
python .claude\fix_dialplate_skin.py
```

该脚本会更新 `.claude/skin_new_240.png` 和 `img_src_dialplate_skin.c`。

## 图标和中文字库

图标字体资源：

```text
Tools\图标\font_8tb3b7jawi9\iconfont.ttf
USER/App/Resource/Font/font_iconfont_20.c
```

转换脚本：

```powershell
Tools\图标\convert_iconfont.bat --no-pause
```

中文字库由 `Tools/font_gen` 生成。如果新增中文文本，先把字符加入字体配置，再执行项目已有字体生成脚本。

## 验证流程

模拟器编译：

```powershell
cd Simulator
D:\vs2019\MSBuild\Current\Bin\MSBuild.exe LVGL.Simulator.sln -p:Configuration=Debug -p:Platform=x64 -m -v:minimal -nologo
```

截图：

```powershell
cd ..
powershell -NoProfile -ExecutionPolicy Bypass -File .\.claude\cap.ps1
```

截图输出：

```text
.claude/sim_new.png
```

设备固件构建时，改了 Dialplate 代码通常编译：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& .\MDK-ARM_F435\build_f435.ps1 -Sources @('..\USER\App\Pages\Dialplate\Dialplate.cpp','..\USER\App\Pages\Dialplate\DialplateModel.cpp','..\USER\App\Pages\Dialplate\DialplateView.cpp')"
```

如果改了底图资源 `img_src_dialplate_skin.c`，也要把该资源加入构建源列表。
