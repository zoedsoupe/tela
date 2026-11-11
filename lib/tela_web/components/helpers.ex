defmodule TelaWeb.Components.Helpers do
  @moduledoc "Small LiveView transition helpers shared by semantic components."
  alias Phoenix.LiveView.JS

  @doc "Shows a target with a short opacity and position transition."
  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 150,
      transition:
        {"transition-all ease-out duration-150", "opacity-0 translate-y-1",
         "opacity-100 translate-y-0"}
    )
  end

  @doc "Hides a target with a short opacity transition."
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 120,
      transition: {"transition-opacity ease-in duration-100", "opacity-100", "opacity-0"}
    )
  end
end
