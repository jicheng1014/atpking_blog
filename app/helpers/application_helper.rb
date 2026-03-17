module ApplicationHelper
  include Pagy::Frontend

  def nav_link_class(active)
    base = "text-sm transition-colors"
    active ? "#{base} text-stone-900 font-medium" : "#{base} text-stone-500 hover:text-stone-800"
  end

  def mobile_nav_link_class(active)
    base = "block px-3 py-2 text-sm rounded-md transition-colors"
    active ? "#{base} text-stone-900 font-medium bg-stone-100" : "#{base} text-stone-500 hover:text-stone-800 hover:bg-stone-100"
  end
end
