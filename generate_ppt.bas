Attribute VB_Name = "GenerateNexusPPT"
Sub GenerateNexusProposalPPT()
    Dim pptApp As Object
    Dim pptPres As Object
    Dim slideIndex As Integer
    
    ' Create PowerPoint instance
    On Error Resume Next
    Set pptApp = GetObject(, "PowerPoint.Application")
    If Err.Number <> 0 Then
        Set pptApp = CreateObject("PowerPoint.Application")
    End If
    On Error GoTo 0
    
    pptApp.Visible = True
    Set pptPres = pptApp.Presentations.Add
    slideIndex = 1

    ' Helper to add slide
    ' Layouts: 1=Title, 2=Text, 11=Title Only
    
    ' Slide 1: Title
    With pptPres.Slides.Add(slideIndex, 1) ' ppLayoutTitle
        .Shapes(1).TextFrame.TextRange.Text = "关于搭建公司内部依赖私服仓库的建议方案"
        .Shapes(2).TextFrame.TextRange.Text = "低投入、高产出、安全可控的基础设施建设"
    End With
    slideIndex = slideIndex + 1

    ' Slide 2: Background
    With pptPres.Slides.Add(slideIndex, 2) ' ppLayoutText
        .Shapes(1).TextFrame.TextRange.Text = "一、背景与痛点"
        .Shapes(2).TextFrame.TextRange.Text = _
            "目前公司开发环境网络受限，存在以下问题：" & vbCrLf & _
            "1. 开发效率低下：频繁申请网络，中断节奏" & vbCrLf & _
            "2. 网络权限分散：难以统一管理，有泄露风险" & vbCrLf & _
            "3. 依赖版本不一致：“在我这能跑”" & vbCrLf & _
            "4. 重复下载浪费带宽：占用公司出口带宽"
    End With
    slideIndex = slideIndex + 1

    ' Slide 3: Solution
    With pptPres.Slides.Add(slideIndex, 2)
        .Shapes(1).TextFrame.TextRange.Text = "二、解决方案：Nexus 私服"
        .Shapes(2).TextFrame.TextRange.Text = _
            "推荐使用：Sonatype Nexus Repository Manager OSS" & vbCrLf & vbCrLf & _
            "核心机制：" & vbCrLf & _
            "• 代理模式 (Proxy)：私服代理公网，内网直接拉取" & vbCrLf & _
            "• 缓存机制 (Cache)：一次下载，永久缓存，秒级响应" & vbCrLf & _
            "• 私有托管 (Hosted)：统一管理内部研发公共组件"
    End With
    slideIndex = slideIndex + 1

    ' Slide 4: Supported Types
    With pptPres.Slides.Add(slideIndex, 2)
        .Shapes(1).TextFrame.TextRange.Text = "支持的依赖类型"
        .Shapes(2).TextFrame.TextRange.Text = _
            "• Maven/Gradle (Java/Android)" & vbCrLf & _
            "• npm/Yarn (Node.js/Web)" & vbCrLf & _
            "• PyPI (Python/AI)" & vbCrLf & _
            "• Docker (容器镜像)" & vbCrLf & _
            "• Go Modules, NuGet, 等"
    End With
    slideIndex = slideIndex + 1

    ' Slide 5: ROI
    With pptPres.Slides.Add(slideIndex, 2)
        .Shapes(1).TextFrame.TextRange.Text = "三、核心收益 (ROI)"
        .Shapes(2).TextFrame.TextRange.Text = _
            "1. 效率提升：内网千兆下载，节省大量等待时间" & vbCrLf & _
            "2. 安全管控：网络权限收口，仅需开通服务器白名单" & vbCrLf & _
            "3. 精细权限：支持 RBAC，保护核心代码资产" & vbCrLf & _
            "4. 资产沉淀：避免重复造轮子，提升复用率"
    End With
    slideIndex = slideIndex + 1

    ' Slide 6: Permission
    With pptPres.Slides.Add(slideIndex, 2)
        .Shapes(1).TextFrame.TextRange.Text = "四、权限管理方案"
        .Shapes(2).TextFrame.TextRange.Text = _
            "网络层面：" & vbCrLf & _
            "• 源头控制：仅服务器可访问公网" & vbCrLf & _
            "• 客户端控制：开发机完全内网" & vbCrLf & vbCrLf & _
            "应用层面 (RBAC)：" & vbCrLf & _
            "• 禁止匿名访问，强制实名登录" & vbCrLf & _
            "• 严格控制发布 (Deploy) 权限"
    End With
    slideIndex = slideIndex + 1

    ' Slide 7: Compliance
    With pptPres.Slides.Add(slideIndex, 2)
        .Shapes(1).TextFrame.TextRange.Text = "五、开源合规与风险控制"
        .Shapes(2).TextFrame.TextRange.Text = _
            "1. 商业版方案：Nexus Firewall (自动拦截风险组件)" & vbCrLf & _
            "2. 低成本方案：CI/CD 流水线集成扫描 (license-checker)" & vbCrLf & _
            "3. 流程控制：首次引入新依赖需人工审核 License"
    End With
    slideIndex = slideIndex + 1

    ' Slide 8: Plan & Cost
    With pptPres.Slides.Add(slideIndex, 2)
        .Shapes(1).TextFrame.TextRange.Text = "六、实施计划与成本"
        .Shapes(2).TextFrame.TextRange.Text = _
            "• 技术选型：Nexus OSS (免费)" & vbCrLf & _
            "• 硬件需求：2核 4G/8G 内存，500G+ 硬盘" & vbCrLf & _
            "• 落地周期：1-2 个工作日" & vbCrLf & _
            "• 维护成本：极低 (定期备份)"
    End With
    slideIndex = slideIndex + 1

    ' Slide 9: Summary
    With pptPres.Slides.Add(slideIndex, 1)
        .Shapes(1).TextFrame.TextRange.Text = "总结"
        .Shapes(2).TextFrame.TextRange.Text = "低投入、高产出" & vbCrLf & "解决网络痛点，确保安全合规"
    End With
    
    MsgBox "PPT 生成完成！", vbInformation
End Sub
