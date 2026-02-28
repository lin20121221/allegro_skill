;;==============================================================================
;; layers.il Etch层选择
;;==============================================================================

JL_paletteForm  = nil
JL_layerButtons = nil

procedure(JL_getFormPath()
  let((pcbPath parts dir)
    pcbPath = axlCurrentDesign()
    if(pcbPath && pcbPath != "" then
        ;; 将路径按斜杠拆分
        parts = parseString(pcbPath "/\\")
        ;; 移除最后一个元素（文件名），重新拼接目录
        if(length(parts) > 1 then
            dir = buildString(reverse(cdr(reverse(parts))) "/")
            ;; 处理 Windows 盘符开头的情况
            if(rexMatchp("^[A-Z]:" car(parts)) then
                strcat(dir "/jl_layers.form")
            else
                strcat("/" dir "/jl_layers.form")
            )
        else
            strcat(getWorkingDir() "/jl_layers.form")
        )
    else
        strcat(getWorkingDir() "/jl_layers.form")
    )
  )
)

;;JL_tempFile     = strcat(getWorkingDir() "/jl_layers.form")

procedure(JL_getSafeName(lName)
  let((s)
    s = lName
    while(rexMatchp(" " s) s = rexReplace(s "_" 0))
    while(rexMatchp("/" s) s = rexReplace(s "_" 0))
    s
  )
)

;; 1. Form Writer: 确保色块与按钮宽度 FSIZE 绝对对齐
procedure(JL_WriteCompactForm(fileName layers)
  let((p numLayers idx btnW btnH maxCols x y safeName colGap rowGap formWidth formHeight)
    numLayers = length(layers)
    maxCols = numLayers
    
    ;; 统一计算宽度，确保两者使用同一个变量
    formWidth  = numLayers*20+10
    formHeight = 20 

    colGap = 2
    btnH = 2 
    rowGap = 2
    btnW = fix( (formWidth-10 - ((numLayers-1)*colGap)) / numLayers)
    
    
    p = outfile(fileName "w")
    when(p
      fprintf(p "FILE_TYPE=FORM_DEFN VERSION=2\nFORM\nFIXED\n")
      fprintf(p "PORT %d %d\nHEADER \"Layer Selection\"\nTILE\n" formWidth formHeight)

      idx = 0
      foreach(ly layers
        safeName = JL_getSafeName(car(ly))
        x = 5 + idx * (btnW + colGap)
        y = 5
        fprintf(p "FIELD JL_btn_%s\nFLOC %d %d\nMENUBUTTON \"%s\" %d %d\nENDFIELD\n" 
                safeName x y car(ly) btnW btnH)
        ;; 绘制色块：宽度设为 btnW，确保与按钮一致
        fprintf(p "FIELD JL_col_%s\nFLOC %d %d\nCOLOR 0\nFSIZE %d 1\nENDFIELD\n" 
                safeName x y 1)
                

        idx++
      )

      let((baseY bw)
        baseY = (btnH + rowGap + 5)
        bw = fix( (formWidth - 20 - 15) / 4 )
        fprintf(p "FIELD JL_allOn\nFLOC 10 %d\nMENUBUTTON \"ALL ON\" %d 1\nENDFIELD\n" baseY bw)
        fprintf(p "FIELD JL_allOff\nFLOC %d %d\nMENUBUTTON \"ALL OFF\" %d 1\nENDFIELD\n" (15 + bw) baseY bw)
        fprintf(p "FIELD JL_sync\nFLOC %d %d\nMENUBUTTON \"SYNC\" %d 1\nENDFIELD\n" (20 + 2*bw) baseY bw)
        fprintf(p "FIELD JL_close\nFLOC %d %d\nMENUBUTTON \"EXIT\" %d 1\nENDFIELD\n" (25 + 3*bw) baseY bw)
      )
      fprintf(p "ENDTILE\nENDFORM\n")
      close(p)
      t
    )
  )
)

;; 2. 刷新函数：增加颜色开关逻辑，取消星号
procedure(JL_RefreshLayerDisplay(form lName)
  let((safeName btnField colField isVis lColor layerObj)
    safeName = JL_getSafeName(lName)
    btnField = strcat("JL_btn_" safeName)
    colField = strcat("JL_col_" safeName)
    
    ;; 检查可见性
    isVis = axlIsVisibleLayer(strcat("ETCH/" lName))
    
    ;; --- 需求 3: 取消星号，只保持原名 ---
    axlFormSetField(form btnField lName)
    
    ;; --- 需求 1: 颜色跟随 ON/OFF 状态 ---
    if(isVis then
        ;; 如果层是 ON，显示真实颜色
        layerObj = axlLayerGet(strcat("ETCH/" lName))
        lColor = if(layerObj layerObj->color 0)
    else
        ;; 如果层是 OFF，将色块设为黑色 (索引 0)
        lColor = 0
    )
    
    ;; 动态设置色块颜色
    axlFormSetField(form colField lColor)
  )
)

;; 3. Callback 逻辑
procedure(JL_Callback(form)
  case(form->curField
    ("JL_close" axlFormClose(form) JL_paletteForm = nil)
    ("JL_sync" JL_showEtchPalette(?force t))
    ("JL_allOn"
      let((etch) etch = axlGetParam("paramLayerGroup:ETCH")
      when(etch 
        foreach(m etch->groupMembers 
          axlVisibleLayer(strcat("ETCH/" m) t)
          JL_RefreshLayerDisplay(form m)
        )
        axlFlushDisplay()
      ))
    )
    ("JL_allOff"
      let((etch) etch = axlGetParam("paramLayerGroup:ETCH")
      when(etch 
        foreach(m etch->groupMembers 
          axlVisibleLayer(strcat("ETCH/" m) nil)
          JL_RefreshLayerDisplay(form m)
        )
        axlFlushDisplay()
      ))
    )
    (t
      foreach(m JL_layerButtons
        let((lName btnField)
          lName = car(m)
          btnField = strcat("JL_btn_" JL_getSafeName(lName))
          when(btnField == form->curField
            ;; 点击即切换
            if(axlIsVisibleLayer(strcat("ETCH/" lName)) then
              axlVisibleLayer(strcat("ETCH/" lName) nil)
            else
              axlSetActiveLayer(strcat("ETCH/" lName))
              axlVisibleLayer(strcat("ETCH/" lName) t)
            )
            JL_RefreshLayerDisplay(form lName)
            axlFlushDisplay()
          )
        )
      )
    )
  )
)

;; 4. Main Entry
procedure(JL_showEtchPalette(@key (force nil))
  let((etchClass layers)
    JL_tempFile = JL_getFormPath()
    etchClass = axlGetParam("paramLayerGroup:ETCH")
    if(etchClass then
      layers = mapcar(lambda((s) list(s)) etchClass->groupMembers)
      JL_layerButtons = layers
      
      when(force || !isFile(JL_tempFile)
          JL_WriteCompactForm(JL_tempFile layers)
          printf("Creating form file: %s\n" JL_tempFile)
      )

      ;; 创建并显示表单
      when(isFile(JL_tempFile)
        when(JL_paletteForm && axlIsFormType(JL_paletteForm)
          errset(axlFormClose(JL_paletteForm) nil)
        )
        JL_paletteForm = axlFormCreate('JL JL_tempFile '(shared) 'JL_Callback t)
        when(JL_paletteForm 
            axlFormDisplay(JL_paletteForm)
            foreach(m layers JL_RefreshLayerDisplay(JL_paletteForm car(m)))
        )
      )    else
      printf("No ETCH layers detected.\n")
    )
  )
)

axlCmdRegister("JL_LayerPalette" "JL_showEtchPalette")
