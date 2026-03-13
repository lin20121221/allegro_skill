;;==============================================================================
;; layers_sel.il
;; 左键点层名：切换显示/设为当前层
;; 左键点色块：弹出颜色选择框并修改该层颜色
;;==============================================================================

JL_paletteForm  = nil
JL_layerButtons = nil
JL_activeLayer  = nil  ;; 当前激活的 ETCH 层名（不含 ETCH/ 前缀）

procedure(JL_getSafeName(lName)
  let((s)
    s = lName
    while(rexMatchp(" " s) s = rexReplace(s "_" 0))
    while(rexMatchp("/" s) s = rexReplace(s "_" 0))
    while(rexMatchp("-" s) s = rexReplace(s "_" 0))
    while(rexMatchp("\\." s) s = rexReplace(s "_" 0))
    s
  )
)

procedure(JL_LayerPath(lName)
  strcat("ETCH/" lName)
)

;; 生成 inline FORM 文本。
;; 每个非空行前都加一个 TAB。
procedure(JL_BuildCompactFormText(layers)
  let((numLayers idx btnW btnH colW maxCols x y safeName colGap rowGap formWidth formHeight txt bw baseY)
    numLayers = length(layers)
    maxCols = numLayers

    formWidth  = max(70 numLayers * 20 + 10)
    formHeight = 20

    colGap = 2
    btnH   = 2
    rowGap = fix((formHeight - 2 * btnH) / 3)
    rowGap = max(2 rowGap)
    btnW   = fix((formWidth - 10 - ((numLayers - 1) * colGap)) / numLayers)
    colW   = max(3 min(btnW 6))

    txt = ""
    txt = strcat(txt "\tFILE_TYPE=FORM_DEFN VERSION=2\n")
    txt = strcat(txt "\tFORM\n")
    txt = strcat(txt "\tFIXED\n")
    txt = strcat(txt sprintf(nil "\tPORT %d %d\n" formWidth formHeight))
    txt = strcat(txt "\tHEADER \"Layer Selection\"\n")
    txt = strcat(txt "\tTILE\n")

    idx = 0
    foreach(ly layers
      safeName = JL_getSafeName(car(ly))
      x = 5 + idx * (btnW + colGap)
      y = rowGap

      txt = strcat(txt sprintf(nil
        "\tFIELD JL_btn_%s\n\tFLOC %d %d\n\tMENUBUTTON \"%s\" %d %d\n\tENDFIELD\n"
        safeName x y car(ly) btnW btnH
      ))

      txt = strcat(txt sprintf(nil
        "\tFIELD JL_col_%s\n\tFLOC %d %d\n\tCOLOR 0\n\tFSIZE %d 1\n\tENDFIELD\n"
        safeName x y colW
      ))

      idx++
    )

    baseY = rowGap + btnH + rowGap
    bw = fix((formWidth - 20 - 15) / 4)

    txt = strcat(txt sprintf(nil
      "\tFIELD JL_allOn\n\tFLOC 10 %d\n\tMENUBUTTON \"ALL ON\" %d 1\n\tENDFIELD\n"
      baseY bw
    ))
    txt = strcat(txt sprintf(nil
      "\tFIELD JL_allOff\n\tFLOC %d %d\n\tMENUBUTTON \"ALL OFF\" %d 1\n\tENDFIELD\n"
      (15 + bw) baseY bw
    ))
    txt = strcat(txt sprintf(nil
      "\tFIELD JL_sync\n\tFLOC %d %d\n\tMENUBUTTON \"SYNC\" %d 1\n\tENDFIELD\n"
      (20 + 2 * bw) baseY bw
    ))
    txt = strcat(txt sprintf(nil
      "\tFIELD JL_close\n\tFLOC %d %d\n\tMENUBUTTON \"EXIT\" %d 1\n\tENDFIELD\n"
      (25 + 3 * bw) baseY bw
    ))

    txt = strcat(txt "\tENDTILE\n")
    txt = strcat(txt "\tENDFORM\n")

    txt
  )
)

procedure(JL_RefreshLayerDisplay(form lName)
  let((safeName btnField colField isVis lColor layerObj dispColor)
    safeName = JL_getSafeName(lName)
    btnField = strcat("JL_btn_" safeName)
    colField = strcat("JL_col_" safeName)

    isVis = axlIsVisibleLayer(JL_LayerPath(lName))
    let((isActive btnLabel)
      isActive = (JL_activeLayer == lName)
      btnLabel = if(isActive strcat("* " lName) lName)
      axlFormSetField(form btnField btnLabel)
    )

    layerObj = axlLayerGet(JL_LayerPath(lName))
    lColor = if(layerObj && numberp(layerObj->color) layerObj->color 0)
    dispColor = if(isVis lColor 0)

    ;; 先切到黑色，再切回目标色，尽量触发 COLOR 字段重绘。
    axlFormSetField(form colField 0)
    axlFormSetField(form colField dispColor)
    axlFlushDisplay()
  )
)

procedure(JL_SetLayerColor(form lName)
  let((layerObj colorNum oldRgb newRgb)
    if(axlIsVisibleLayer(JL_LayerPath(lName)) then
      layerObj = axlLayerGet(JL_LayerPath(lName))
      when(layerObj
        colorNum = if(numberp(layerObj->color) layerObj->color 1)
        oldRgb = axlColorGet(colorNum)
        when(!oldRgb
          oldRgb = '(255 255 255)
        )
        newRgb = axlUIColorDialog(nil oldRgb)
        when(listp(newRgb)
          axlColorSet(colorNum newRgb)
          axlVisibleUpdate(t)
          ;; 不重建 palette，直接刷新这个色块。
          JL_RefreshLayerDisplay(form lName)
          axlFlushDisplay()
        )
      )
    else
      nil
    )
  )
)

procedure(JL_ToggleLayer(form lName)
  if(axlIsVisibleLayer(JL_LayerPath(lName)) then
    axlVisibleLayer(JL_LayerPath(lName) nil)
    JL_RefreshLayerDisplay(form lName)
  else
    axlSetActiveLayer(JL_LayerPath(lName))
    axlVisibleLayer(JL_LayerPath(lName) t)
    JL_activeLayer = lName
    foreach(m JL_layerButtons
      JL_RefreshLayerDisplay(form car(m))
    )
  )
  axlFlushDisplay()
)

procedure(JL_Callback(form)
  case(form->curField
    ("JL_close"
      axlFormClose(form)
      JL_paletteForm = nil
    )
    ("JL_sync"
      JL_showEtchPalette(?force t)
    )
    ("JL_allOn"
      let((etch)
        etch = axlGetParam("paramLayerGroup:ETCH")
        when(etch
          foreach(m etch->groupMembers
            axlVisibleLayer(JL_LayerPath(m) t)
            JL_RefreshLayerDisplay(form m)
          )
          axlFlushDisplay()
        )
      )
    )
    ("JL_allOff"
      let((etch)
        etch = axlGetParam("paramLayerGroup:ETCH")
        when(etch
          foreach(m etch->groupMembers
            axlVisibleLayer(JL_LayerPath(m) nil)
            JL_RefreshLayerDisplay(form m)
          )
          axlFlushDisplay()
        )
      )
    )
    (t
      foreach(m JL_layerButtons
        let((lName btnField colField)
          lName = car(m)
          btnField = strcat("JL_btn_" JL_getSafeName(lName))
          colField = strcat("JL_col_" JL_getSafeName(lName))
          when(btnField == form->curField
            JL_ToggleLayer(form lName)
          )
          when(colField == form->curField
            JL_SetLayerColor(form lName)
          )
        )
      )
    )
  )
)

procedure(JL_showEtchPalette(@key (force nil))
  let((etchClass layers formText)
    etchClass = axlGetParam("paramLayerGroup:ETCH")
    if(etchClass then
      layers = mapcar(lambda((s) list(s)) etchClass->groupMembers)
      JL_layerButtons = layers
      let((dispParam rawActive guessed)
        dispParam  = axlGetParam("paramDisplay")
        rawActive  = if(dispParam && stringp(dispParam->activeLayer)
                        dispParam->activeLayer "")
        guessed    = nil
        when(rexMatchp("^[Ee][Tt][Cc][Hh]/" rawActive)
          let((sub)
            sub = substring(rawActive 6 strlen(rawActive))   ;; 去掉 "ETCH/"
            foreach(m etchClass->groupMembers
              when(upperCase(m) == upperCase(sub)
                guessed = m
              )
            )
          )
        )
        JL_activeLayer = if(guessed guessed car(etchClass->groupMembers))
      )
      formText = JL_BuildCompactFormText(layers)

      when(JL_paletteForm && axlIsFormType(JL_paletteForm)
        errset(axlFormClose(JL_paletteForm) nil)
      )

      JL_paletteForm = axlFormCreate(
        'JL
        list("jl_layers_inline" formText)
        '(shared)
        'JL_Callback
        t
      )

      when(JL_paletteForm
        axlFormDisplay(JL_paletteForm)
        foreach(m layers
          JL_RefreshLayerDisplay(JL_paletteForm car(m))
        )
      )
    else
      printf("No ETCH layers detected.\n")
    )
  )
)

axlCmdRegister("JL_LayerPalette" "JL_showEtchPalette")
