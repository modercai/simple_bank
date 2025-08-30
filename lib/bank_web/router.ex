defmodule BankWeb.Router do
  use BankWeb, :router

  import BankWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BankWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BankWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", BankWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:bank, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BankWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", BankWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{BankWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    # Admin-only routes
    live_session :require_admin,
      on_mount: [{BankWeb.UserAuth, :require_authenticated}, {BankWeb.UserAuth, :require_admin}] do
      live "/admin/customers", AdminLive.Customers, :index
      live "/admin/accounts", AdminLive.Accounts, :index
      live "/admin/accounts/new", AdminLive.Accounts.New, :new
      live "/admin/transactions", AdminLive.Transactions, :index
    end

    # Customer-only routes  
    live_session :require_customer,
      on_mount: [{BankWeb.UserAuth, :require_authenticated}, {BankWeb.UserAuth, :require_customer}] do
      live "/dashboard", CustomerLive.Dashboard, :index
      live "/accounts/:id", CustomerLive.Account, :show
      live "/transactions", CustomerLive.Transactions, :index
      live "/transfer", CustomerLive.Transfer, :new
      live "/withdraw", CustomerLive.Withdraw, :new
      live "/deposit", CustomerLive.Deposit, :new
    end

    post "/users/update-password", UserSessionController, :update_password
  end


  scope "/", BankWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{BankWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
