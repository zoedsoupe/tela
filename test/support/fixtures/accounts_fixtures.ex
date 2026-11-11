defmodule Tela.AccountsFixtures do
  @moduledoc "Accounts fixtures shared by context and web contract tests."

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      name: "Pessoa Teste",
      password: "senha muito segura"
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} = attrs |> valid_user_attributes() |> Tela.Accounts.register_user()
    user
  end
end
