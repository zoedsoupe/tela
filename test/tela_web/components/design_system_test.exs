defmodule TelaWeb.Components.DesignSystemTest do
  use ExUnit.Case, async: true
  import Phoenix.Component
  import TelaWeb.Components.Actions
  import TelaWeb.Components.Forms

  test "button exposes semantic variants and loading state" do
    assigns = %{}

    html =
      Phoenix.HTML.Safe.to_iodata(~H"""
      <.button id="save-button" variant={:primary} size={:lg} loading>Salvando</.button>
      """)
      |> IO.iodata_to_binary()

    button = html |> LazyHTML.from_fragment() |> LazyHTML.query("#save-button")
    assert LazyHTML.attribute(button, "data-variant") == ["primary"]
    assert LazyHTML.attribute(button, "data-size") == ["lg"]
    assert LazyHTML.attribute(button, "aria-busy") == ["true"]
    assert LazyHTML.attribute(button, "disabled") == [""]
  end

  test "button renders navigation through Phoenix link" do
    assigns = %{}

    html =
      Phoenix.HTML.Safe.to_iodata(~H"""
      <.button id="home-link" variant={:ghost} href="/">Início</.button>
      """)
      |> IO.iodata_to_binary()

    link = html |> LazyHTML.from_fragment() |> LazyHTML.query("a#home-link")
    assert LazyHTML.attribute(link, "href") == ["/"]
    assert LazyHTML.attribute(link, "data-variant") == ["ghost"]
  end

  test "input associates label, hint, and error with the control" do
    assigns = %{}

    html =
      Phoenix.HTML.Safe.to_iodata(~H"""
      <.input
        id="design-title"
        name="title"
        label="Título"
        hint="Use um nome curto"
        errors={["Informe o título"]}
      />
      """)
      |> IO.iodata_to_binary()

    document = LazyHTML.from_fragment(html)
    input = LazyHTML.query(document, "input#design-title")
    assert LazyHTML.attribute(input, "aria-invalid") == ["true"]

    assert LazyHTML.attribute(input, "aria-describedby") == [
             "design-title-hint design-title-error"
           ]

    assert LazyHTML.query(document, "label[for='design-title']") |> LazyHTML.text() == "Título"

    assert LazyHTML.query(document, "#design-title-error") |> LazyHTML.text() |> String.trim() ==
             "Informe o título"
  end

  test "additional input classes preserve semantic base classes" do
    assigns = %{}

    html =
      Phoenix.HTML.Safe.to_iodata(~H"""
      <.input id="custom-input" name="custom" class="max-w-sm" />
      """)
      |> IO.iodata_to_binary()

    input = html |> LazyHTML.from_fragment() |> LazyHTML.query("#custom-input")
    assert [class] = LazyHTML.attribute(input, "class")
    assert class =~ "bg-surface"
    assert class =~ "max-w-sm"
  end
end
