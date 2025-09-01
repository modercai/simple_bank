# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your repositories directly:
#
#     Bank.Repo.insert!(%Bank.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Bank.{Accounts, Repo}
alias Bank.Accounts.User
import Ecto.Query

IO.puts("Starting database seeding...")

# Create default admin user
create_admin_user = fn ->
  admin_email = "admin@bank.com"

  # Check if admin already exists
  case Repo.get_by(User, email: admin_email) do
    nil ->
      IO.puts("Creating admin user...")

      admin_attrs = %{
        email: admin_email,
        password: "adminpassword123",
        nrc: "000000/00/0",
        role: "admin",
        status: "active"
      }

      case Accounts.create_customer(admin_attrs) do
        {:ok, admin} ->
          # Confirm the admin user immediately
          admin
          |> User.confirm_changeset()
          |> Repo.update!()

          IO.puts("Admin user created successfully!")
          IO.puts("   Password: adminpassword123")
          admin

        {:error, changeset} ->
          IO.puts("❌ Failed to create admin user:")
          Enum.each(changeset.errors, fn {field, {message, _}} ->
            IO.puts("   #{field}: #{message}")
          end)
          nil
      end

    existing_admin ->
      IO.puts("Admin user already exists: #{existing_admin.email}")
      existing_admin
  end
end

# Create sample customer (optional)
create_sample_customer = fn ->
  customer_email = "customer@example.com"

  case Repo.get_by(User, email: customer_email) do
    nil ->
      IO.puts("Creating sample customer...")

      customer_attrs = %{
        email: customer_email,
        password: "customerpass123",
        nrc: "123456789",
        role: "customer",
        status: "active"
      }

      case Accounts.create_customer(customer_attrs) do
        {:ok, customer} ->
          # Confirm the customer
          customer
          |> User.confirm_changeset()
          |> Repo.update!()
          customer

        {:error, changeset} ->
          IO.puts("Failed to create sample customer:")
          Enum.each(changeset.errors, fn {field, {message, _}} ->
            IO.puts("   #{field}: #{message}")
          end)
          nil
      end

    existing_customer ->
      IO.puts("Sample customer already exists: #{existing_customer.email}")
      existing_customer
  end
end

create_sample_account = fn
  user when not is_nil(user) ->
    existing_account = Repo.get_by(Bank.Accounts.Account, user_id: user.id)

    case existing_account do
      nil ->
        IO.puts("Creating sample account for #{user.email}...")

        account_attrs = %{
          number: "ACC#{String.pad_leading(to_string(user.id), 8, "0")}",
          balance: Decimal.new("1000.00"),
          user_id: user.id
        }

        case Accounts.create_account(account_attrs) do
          {:ok, account} ->
            IO.puts("Sample account created: #{account.number} (Balance: ZMW #{account.balance})")
            account

          {:error, changeset} ->
            IO.puts("Failed to create sample account:")
            Enum.each(changeset.errors, fn {field, {message, _}} ->
              IO.puts("   #{field}: #{message}")
            end)
            nil
        end

      existing_account ->
        IO.puts("Account already exists for #{user.email}: #{existing_account.number}")
        existing_account
    end

  _ -> nil
end

# Run the seeding
try do
  # Create admin user
  admin = create_admin_user.()

  #the lines below are for safety just maybe weh testing and the system  is not wokring, the developer should try and create sample accounts

  # customer = create_sample_customer.()
  # create_sample_account.(customer)

  IO.puts("\n🎉 Database seeding completed successfully!")

  if admin do
    IO.puts("\nAccess admin at: http://localhost:4000/admin/customers")
  end

rescue
  error ->
    IO.puts("\n❌ Error during seeding: #{inspect(error)}")
    reraise error, __STACKTRACE__
end
