defmodule Tela.AccountsTest do
  use Tela.DataCase, async: false
  import Tela.AccountsFixtures
  alias Tela.Accounts

  test "registers a user with normalized email and hashed password" do
    email = unique_user_email()

    assert {:ok, user} =
             Accounts.register_user(%{
               email: String.upcase(email),
               name: "Zoey",
               password: "senha muito segura"
             })

    assert user.email == email
    assert user.name == "Zoey"
    refute Map.has_key?(user, :password)
    assert user.hashed_password != "senha muito segura"

    assert {:ok, authenticated} =
             Accounts.get_user_by_email_and_password(email, "senha muito segura")

    assert authenticated.id == user.id
  end

  test "rejects duplicate emails and invalid credentials" do
    user = user_fixture()

    assert {:error, changeset} =
             Accounts.register_user(%{
               email: user.email,
               name: "Outra",
               password: "senha muito segura"
             })

    assert %{email: [_ | _]} = errors_on(changeset)

    assert {:error, :invalid_credentials} =
             Accounts.get_user_by_email_and_password(user.email, "incorrect")
  end
end
