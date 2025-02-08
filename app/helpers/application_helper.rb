module ApplicationHelper
  def nav_link_class(active)
    base_classes = "inline-flex items-center px-1 pt-1 text-sm font-medium border-b-2"
    if active
      "#{base_classes} border-blue-500 text-gray-900"
    else
      "#{base_classes} border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
    end
  end
end
