import { Application } from "@hotwired/stimulus"

import ThemeController from "./theme_controller"
import DropdownController from "./dropdown_controller"
import MobileSidebarController from "./mobile_sidebar_controller"

const application = Application.start()

application.register("theme", ThemeController)
application.register("dropdown", DropdownController)
application.register("mobile-sidebar", MobileSidebarController)

window.Stimulus = application
