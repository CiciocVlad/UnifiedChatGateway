defmodule ChatWeb.SubscriptionView do
  use ChatWeb, :view
  alias ChatWeb.SubscriptionView

  def render("show.json", %{subscription: subscription}) do
    render_one(subscription, SubscriptionView, "subscription.json")
  end

  def render("subscription.json", %{subscription: subscription}) do
    %{
      contactid: subscription.id
    }
  end

  def render("transcript.json", %{transcript: transcript}) do
    transcript
  end

  def render(_, _) do
    %{}
  end
end
