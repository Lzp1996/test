# GitHub + Claude 自动化系统流程图

## 1. 整体架构流程图

```mermaid
graph TB
    Start([开发者提交 PR]) --> Auth{认证配置}
    Auth -->|ANTHROPIC_API_KEY| API[API Key 认证]
    Auth -->|ANTHROPIC_AUTH_TOKEN| Token[Auth Token 认证]
    Auth -->|中转服务| Proxy[代理服务认证]
    
    API --> Review[Claude Code 审查]
    Token --> Review
    Proxy --> Review
    
    Review --> JSON{生成 JSON 结果}
    JSON --> Risk[风险级别评估]
    JSON --> Pass{是否通过?}
    
    Risk --> Low[🟢 Low Risk]
    Risk --> Medium[🟡 Medium Risk]
    Risk --> High[🔴 High Risk]
    
    Pass -->|通过| CheckRisk{检查风险级别}
    Pass -->|未通过| CanFix{可自动修复?}
    
    CheckRisk -->|Low + 通过| AutoDeploy[✅ 自动部署]
    CheckRisk -->|Medium| NeedConfirm[⚠️ 需要人工确认]
    CheckRisk -->|High| NeedReview[🔴 必须人工审核]
    
    CanFix -->|是| AutoFix[🔧 Claude 自动修复]
    CanFix -->|否| NeedReview
    
    AutoFix --> FixSuccess{修复成功?}
    FixSuccess -->|是| Review
    FixSuccess -->|否 达到重试上限| NeedReview
    
    AutoDeploy --> Build[构建应用]
    Build --> Validate[验证构建]
    Validate --> Backup[备份构建产物]
    Backup --> Deploy[部署到 GitHub Pages]
    Deploy --> Health[健康检查]
    
    Health -->|通过| Tag[创建部署标签]
    Health -->|失败| RollbackPrompt[提示回滚]
    
    Tag --> Success([✅ 部署成功])
    RollbackPrompt --> Manual[人工决策]
    
    NeedConfirm --> HumanCheck{人工确认}
    HumanCheck -->|批准| AutoDeploy
    HumanCheck -->|拒绝| End([结束])
    
    NeedReview --> HumanReview{人工审核}
    HumanReview -->|批准| AutoDeploy
    HumanReview -->|拒绝| End
    
    Manual -->|回滚| Rollback[执行回滚]
    Manual -->|继续| Success
    
    style Start fill:#e1f5ff
    style Success fill:#d4edda
    style End fill:#f8d7da
    style Review fill:#fff3cd
    style AutoDeploy fill:#d4edda
    style AutoFix fill:#ffeaa7
    style Rollback fill:#ff7675
```

## 2. PR 审查流程详细图

```mermaid
flowchart TD
    PR[PR 创建/更新] --> Trigger[触发 pr-review.yml]
    Trigger --> Setup[安装 Claude Code CLI]
    Setup --> CheckAuth{检查认证}
    
    CheckAuth -->|有 AUTH_TOKEN| UseToken[使用 Auth Token]
    CheckAuth -->|有 API_KEY| UseKey[使用 API Key]
    CheckAuth -->|都没有| AuthFail[❌ 认证失败]
    
    UseToken --> GenDiff[生成 PR diff]
    UseKey --> GenDiff
    
    GenDiff --> ClaudeReview[Claude 分析代码]
    ClaudeReview --> ParseJSON[解析 JSON 结果]
    
    ParseJSON --> ResultData{提取审查数据}
    ResultData --> passed[passed: true/false]
    ResultData --> risk[risk_level: low/medium/high]
    ResultData --> canFix[can_auto_fix: true/false]
    ResultData --> needHuman[needs_human_review: true/false]
    
    passed --> CommentPR[在 PR 中评论结果]
    risk --> CommentPR
    canFix --> CommentPR
    needHuman --> CommentPR
    
    CommentPR --> Decision[决策流程]
    Decision --> AddLabel[添加相应标签]
    AddLabel --> SaveArtifact[保存审查结果]
    
    SaveArtifact --> CheckFix{需要自动修复?}
    CheckFix -->|是| AutoFixJob[触发 auto-fix job]
    CheckFix -->|否| DecisionJob[触发 decision job]
    
    AutoFixJob --> FixCode[Claude 修复代码]
    FixCode --> Commit[提交修复]
    Commit --> RePR[重新触发审查]
    
    DecisionJob --> FinalDecision[最终决策]
    FinalDecision --> Done([完成])
    
    style PR fill:#e1f5ff
    style ClaudeReview fill:#fff3cd
    style AutoFixJob fill:#ffeaa7
    style Done fill:#d4edda
    style AuthFail fill:#f8d7da
```

## 3. 部署流程详细图

```mermaid
flowchart TD
    Start[PR 合并到 master] --> CheckLabel{检查标签}
    
    CheckLabel -->|auto-deploy-approved| Continue[继续部署]
    CheckLabel -->|其他标签| Skip[⏸️ 跳过部署]
    
    Continue --> Checkout[拉取代码]
    Checkout --> GetLastDeploy[获取上次成功部署]
    GetLastDeploy --> InstallDeps[安装依赖]
    
    InstallDeps --> Build[npm run build]
    Build --> BuildCheck{构建成功?}
    
    BuildCheck -->|失败| BuildFail[❌ 构建失败]
    BuildCheck -->|成功| ValidateBuild[验证构建]
    
    ValidateBuild --> CheckFiles{检查关键文件}
    CheckFiles -->|缺失| BuildFail
    CheckFiles -->|存在| CheckSize{检查构建大小}
    
    CheckSize -->|太小| BuildFail
    CheckSize -->|正常| BackupBuild[备份构建产物]
    
    BackupBuild --> UploadArtifact[上传到 GitHub]
    UploadArtifact --> DeployPages[部署到 GitHub Pages]
    
    DeployPages --> DeployCheck{部署成功?}
    DeployCheck -->|失败| DeployFail[❌ 部署失败]
    DeployCheck -->|成功| WaitStable[等待部署生效]
    
    WaitStable --> HealthCheck[HTTP 健康检查]
    HealthCheck --> HealthResult{检查结果}
    
    HealthResult -->|HTTP 200| HealthPass[✅ 健康检查通过]
    HealthResult -->|其他| HealthFail[⚠️ 健康检查失败]
    
    HealthPass --> CreateTag[创建 deploy-* 标签]
    CreateTag --> SaveBackup[保存备份 30天]
    SaveBackup --> NotifySuccess[通知部署成功]
    NotifySuccess --> DeploySuccess([✅ 部署完成])
    
    HealthFail --> WarnUser[警告用户]
    WarnUser --> SuggestRollback[建议回滚]
    
    DeployFail --> GetLastTag{有上次部署?}
    GetLastTag -->|有| ShowRollback[显示回滚指引]
    GetLastTag -->|无| NoRollback[无法回滚]
    
    BuildFail --> Notify[通知失败]
    ShowRollback --> Notify
    NoRollback --> Notify
    SuggestRollback --> ManualDecision[人工决策]
    
    Notify --> Failed([❌ 部署失败])
    ManualDecision --> Manual{人工操作}
    Manual -->|回滚| TriggerRollback[触发回滚 workflow]
    Manual -->|修复| FixAndRetry[修复后重试]
    
    Skip --> SkipMsg[评论跳过原因]
    SkipMsg --> End([结束])
    
    style Start fill:#e1f5ff
    style DeploySuccess fill:#d4edda
    style Failed fill:#f8d7da
    style HealthCheck fill:#fff3cd
    style BackupBuild fill:#d1ecf1
```

## 4. 回滚流程详细图

```mermaid
flowchart TD
    Start[触发回滚] --> TriggerType{触发方式}
    
    TriggerType -->|GitHub Actions 手动| Manual[手动回滚 workflow]
    TriggerType -->|本地脚本| Local[quick-rollback.sh]
    TriggerType -->|Git 命令| Git[手动 git 操作]
    
    Manual --> InputTarget{指定目标}
    InputTarget -->|last| FindLast[查找最后部署标签]
    InputTarget -->|tag 名称| UseTag[使用指定标签]
    InputTarget -->|commit SHA| UseCommit[使用指定 commit]
    
    FindLast --> ValidTarget[验证目标有效性]
    UseTag --> ValidTarget
    UseCommit --> ValidTarget
    
    Local --> LocalCheck[检查本地状态]
    LocalCheck --> LocalTarget[确定回滚目标]
    LocalTarget --> CreateBranch[创建回滚分支]
    
    ValidTarget --> CheckoutTarget[检出目标版本]
    CheckoutTarget --> ShowInfo[显示回滚信息]
    ShowInfo --> Confirm{确认回滚}
    
    Confirm -->|取消| Cancel([取消回滚])
    Confirm -->|继续| InstallDeps[安装依赖]
    
    InstallDeps --> BuildTarget[构建目标版本]
    BuildTarget --> BuildOK{构建成功?}
    
    BuildOK -->|失败| BuildError[❌ 构建失败]
    BuildOK -->|成功| ValidateBuild[验证构建]
    
    ValidateBuild --> DeployTarget[部署到 GitHub Pages]
    DeployTarget --> HealthCheck{健康检查}
    
    HealthCheck -->|失败| HealthFail[⚠️ 健康检查失败]
    HealthCheck -->|通过| TagRollback[创建 rollback-* 标签]
    
    TagRollback --> CreateIssue[创建 Issue 记录]
    CreateIssue --> NotifySuccess[通知回滚成功]
    NotifySuccess --> RollbackSuccess([✅ 回滚完成])
    
    CreateBranch --> LocalBuild[本地构建]
    LocalBuild --> LocalOK{构建成功?}
    LocalOK -->|是| ShowOptions[显示后续选项]
    LocalOK -->|否| LocalFail[本地构建失败]
    
    ShowOptions --> Choice{选择操作}
    Choice -->|创建 PR| CreatePR[推送并创建 PR]
    Choice -->|直接部署| ForcePush[强制推送到 master]
    Choice -->|GitHub Actions| UseWorkflow[使用 rollback workflow]
    
    BuildError --> TryBackup{有构建备份?}
    TryBackup -->|有| UseBackup[使用备份产物]
    TryBackup -->|无| RollbackFail[❌ 回滚失败]
    
    HealthFail --> SkipHealth{跳过健康检查?}
    SkipHealth -->|是| TagRollback
    SkipHealth -->|否| RollbackFail
    
    Git --> ManualSteps[手动执行步骤]
    ManualSteps --> ManualDone([手动完成])
    
    style Start fill:#e1f5ff
    style RollbackSuccess fill:#d4edda
    style RollbackFail fill:#f8d7da
    style Cancel fill:#f8d7da
    style HealthCheck fill:#fff3cd
    style Confirm fill:#fff3cd
```

## 5. 认证流程图

```mermaid
flowchart TD
    Start[GitHub Actions 启动] --> LoadSecrets[加载 GitHub Secrets]
    
    LoadSecrets --> CheckToken{检查 ANTHROPIC_AUTH_TOKEN}
    CheckToken -->|存在| ValidToken{验证 Token 格式}
    CheckToken -->|不存在| CheckKey{检查 ANTHROPIC_API_KEY}
    
    ValidToken -->|有效| UseToken[✅ 使用 Auth Token]
    ValidToken -->|无效| TokenError[❌ Token 格式错误]
    
    CheckKey -->|存在| ValidKey{验证 Key 格式}
    CheckKey -->|不存在| NoAuth[❌ 无认证配置]
    
    ValidKey -->|有效| UseKey[✅ 使用 API Key]
    ValidKey -->|无效| KeyError[❌ Key 格式错误]
    
    UseToken --> CheckBase{检查 BASE_URL}
    UseKey --> CheckBase
    
    CheckBase -->|已配置| UseProxy[使用代理服务]
    CheckBase -->|未配置| UseDefault[使用默认 API]
    
    UseProxy --> TestConnection[测试 API 连接]
    UseDefault --> TestConnection
    
    TestConnection --> CallAPI[调用 Claude API]
    CallAPI --> Response{API 响应}
    
    Response -->|200 OK| AuthSuccess[✅ 认证成功]
    Response -->|401| AuthFailed[❌ 认证失败]
    Response -->|403| QuotaError[❌ 配额不足]
    Response -->|其他| NetworkError[❌ 网络错误]
    
    AuthSuccess --> SetEnv[设置环境变量]
    SetEnv --> Ready([准备就绪])
    
    TokenError --> ShowError[显示错误信息]
    KeyError --> ShowError
    NoAuth --> ShowError
    AuthFailed --> ShowError
    QuotaError --> ShowError
    NetworkError --> ShowError
    
    ShowError --> Failed([认证失败])
    
    style Start fill:#e1f5ff
    style Ready fill:#d4edda
    style Failed fill:#f8d7da
    style AuthSuccess fill:#d4edda
    style UseProxy fill:#fff3cd
```

## 6. 决策树流程图

```mermaid
graph TB
    Start{审查结果} --> CheckPassed{是否通过?}
    
    CheckPassed -->|通过| CheckRisk{风险级别}
    CheckPassed -->|未通过| CheckFix{可自动修复?}
    
    CheckRisk -->|Low| CheckHuman1{需要人工?}
    CheckRisk -->|Medium| Medium[🟡 中等风险]
    CheckRisk -->|High| High[🔴 高风险]
    
    CheckHuman1 -->|否| AutoDeploy[✅ 自动部署]
    CheckHuman1 -->|是| NeedReview[需要审核]
    
    Medium --> Confirm[需要人工确认]
    High --> NeedReview
    
    CheckFix -->|是| CheckAttempts{检查重试次数}
    CheckFix -->|否| NeedReview
    
    CheckAttempts -->|0| NeedReview
    CheckAttempts -->|1-3| AutoFix[🔧 自动修复]
    
    AutoFix --> FixResult{修复成功?}
    FixResult -->|是| ReReview[重新审查]
    FixResult -->|否| DecreaseAttempt{还有重试次数?}
    
    DecreaseAttempt -->|是| AutoFix
    DecreaseAttempt -->|否| NeedReview
    
    ReReview --> Start
    
    AutoDeploy --> Label1[添加 auto-deploy-approved]
    Confirm --> Label2[添加 needs-human-approval]
    NeedReview --> Label3[添加 needs-human-review]
    
    Label1 --> Merge{PR 合并?}
    Label2 --> WaitApproval[等待人工批准]
    Label3 --> WaitReview[等待人工审核]
    
    Merge -->|是| Deploy[触发部署]
    Merge -->|否| Wait[等待合并]
    
    WaitApproval --> ApprovalResult{批准结果}
    ApprovalResult -->|批准| Label1
    ApprovalResult -->|拒绝| End1([结束])
    
    WaitReview --> ReviewResult{审核结果}
    ReviewResult -->|批准| Label1
    ReviewResult -->|拒绝| End2([结束])
    
    Deploy --> DeployFlow[部署流程]
    DeployFlow --> Done([完成])
    
    Wait --> Done
    
    style AutoDeploy fill:#d4edda
    style AutoFix fill:#ffeaa7
    style NeedReview fill:#f8d7da
    style Confirm fill:#fff3cd
    style Start fill:#e1f5ff
```

## 7. 时序图 - PR 完整流程

```mermaid
sequenceDiagram
    participant Dev as 开发者
    participant GH as GitHub
    participant Action as GitHub Actions
    participant Claude as Claude API
    participant Pages as GitHub Pages
    
    Dev->>GH: 1. 创建/更新 PR
    GH->>Action: 2. 触发 pr-review workflow
    
    Action->>Action: 3. 检查认证配置
    Action->>Action: 4. 安装 Claude Code CLI
    Action->>Action: 5. 生成 PR diff
    
    Action->>Claude: 6. 发送审查请求
    Note over Claude: 分析代码质量<br/>评估风险级别<br/>检查安全问题
    Claude->>Action: 7. 返回 JSON 结果
    
    Action->>Action: 8. 解析审查结果
    Action->>GH: 9. 在 PR 中评论结果
    Action->>GH: 10. 添加相应标签
    
    alt 需要自动修复
        Action->>Claude: 11. 请求修复代码
        Claude->>Action: 12. 返回修复后的代码
        Action->>GH: 13. 提交修复 commit
        GH->>Action: 14. 重新触发审查
    end
    
    alt 低风险 + 审查通过
        Dev->>GH: 15. 合并 PR
        GH->>Action: 16. 触发 deploy workflow
        
        Action->>Action: 17. 构建应用
        Action->>Action: 18. 备份构建产物
        Action->>Pages: 19. 部署到 GitHub Pages
        
        Action->>Pages: 20. 健康检查
        Pages->>Action: 21. 返回状态
        
        Action->>GH: 22. 创建部署标签
        Action->>GH: 23. 通知部署成功
    end
    
    alt 中高风险
        Action->>Dev: 24. 通知需要人工审核
        Dev->>GH: 25. 人工审核代码
        Dev->>GH: 26. 批准并合并
        GH->>Action: 27. 触发部署
    end
    
    alt 部署失败
        Action->>Dev: 28. 通知失败
        Action->>Dev: 29. 提供回滚选项
        Dev->>Action: 30. 触发回滚 workflow
        Action->>Pages: 31. 回滚到上一版本
    end
```

## 使用说明

以上流程图涵盖了整个自动化系统的：

1. **整体架构** - 系统全貌
2. **PR 审查** - 代码审查详细流程
3. **部署流程** - 从构建到部署的完整步骤
4. **回滚机制** - 三种回滚方式
5. **认证流程** - 双认证支持
6. **决策树** - 自动化决策逻辑
7. **时序图** - 各组件交互时序

可以在支持 Mermaid 的工具中渲染这些图表：
- GitHub README.md
- GitLab
- VS Code (Markdown Preview Mermaid Support 插件)
- Typora
- draw.io
- mermaid.live (在线编辑器)
