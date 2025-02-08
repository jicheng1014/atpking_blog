module ApplicationHelper
  def nav_link_class(active)
    base_classes = "inline-flex items-center px-1 pt-1 text-sm font-medium"
    active ? "#{base_classes} text-gray-900 border-b-2 border-blue-500" : "#{base_classes} text-gray-500 hover:text-gray-700 hover:border-gray-300"
  end

  def mobile_nav_link_class(active)
    base_classes = "block px-4 py-2 text-base font-medium"
    active ? "#{base_classes} text-blue-700 bg-blue-50" : "#{base_classes} text-gray-500 hover:text-gray-800 hover:bg-gray-100"
  end
end
