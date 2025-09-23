import { Application } from "@hotwired/stimulus"

// 导入基础依赖
import './base'

// 启动 Stimulus
const application = Application.start()

// 手动注册控制器（不使用 webpack helpers 保持简单）
import ThemeController from "./controllers/theme_controller"
import DropdownController from "./controllers/dropdown_controller"

application.register("theme", ThemeController)
application.register("dropdown", DropdownController)

// 配置 Stimulus development 经验
application.debug = false
window.Stimulus = application

export { application }
