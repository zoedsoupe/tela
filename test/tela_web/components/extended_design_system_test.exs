defmodule TelaWeb.Components.ExtendedDesignSystemTest do
  use ExUnit.Case, async: true
  import Phoenix.Component
  import TelaWeb.Components.Forms
  import TelaWeb.Components.Feedback
  import TelaWeb.Components.Overlays

  test "switch uses a native checkbox with switch semantics" do
    assigns = %{}

    html =
      Phoenix.HTML.Safe.to_iodata(~H"""
      <.input id="brand-switch" name="brand" type="switch" label="Usar marca" checked />
      """)
      |> IO.iodata_to_binary()

    input = html |> LazyHTML.from_fragment() |> LazyHTML.query("input#brand-switch")
    assert LazyHTML.attribute(input, "type") == ["checkbox"]
    assert LazyHTML.attribute(input, "role") == ["switch"]
    assert LazyHTML.attribute(input, "checked") == [""]
  end

  test "save status includes revision conflicts" do
    assigns = %{}

    html =
      Phoenix.HTML.Safe.to_iodata(~H"""
      <.save_status status={:conflict} />
      """)
      |> IO.iodata_to_binary()

    status = html |> LazyHTML.from_fragment() |> LazyHTML.query("[role='status']")
    assert LazyHTML.attribute(status, "data-state") == ["conflict"]
    assert LazyHTML.text(status) =~ "Conflito"
  end

  test "native dialog remains patchable by LiveView" do
    assigns = %{}

    html =
      Phoenix.HTML.Safe.to_iodata(~H"""
      <.dialog id="export-dialog" labelledby="export-title" open>
        <:title>Exportar</:title>
        Conteúdo
      </.dialog>
      """)
      |> IO.iodata_to_binary()

    dialog = html |> LazyHTML.from_fragment() |> LazyHTML.query("dialog#export-dialog")
    assert LazyHTML.attribute(dialog, "phx-hook") == ["NativeDialog"]
    assert LazyHTML.attribute(dialog, "phx-update") == []
    assert LazyHTML.attribute(dialog, "data-open") == ["true"]
  end
end
