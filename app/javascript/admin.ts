import { Application } from "@hotwired/stimulus"

// 导入基础依赖
import './base'
import './admin/sidebar'

// 启动 Stimulus
const application = Application.start()

// 注册管理后台控制器
import ThemeController from "./controllers/theme_controller"
import DropdownController from "./controllers/dropdown_controller"
import MobileSidebarController from "./controllers/mobile_sidebar_controller"

application.register("theme", ThemeController)
application.register("dropdown", DropdownController)
application.register("mobile-sidebar", MobileSidebarController)

application.debug = false
window.Stimulus = application

export { application }
