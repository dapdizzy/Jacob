defmodule PendingRequests do
  use Agent

  def start_link() do
    Agent.start_link(fn -> %{} end, name: PendingRequests)
  end

  def has_pending_request?(correlation_id) do
    Agent.get(PendingRequests, fn requests -> requests |> Map.has_key?(correlation_id) end)
  end

  def add_pending_request(request, correlation_id) do
    Agent.update(PendingRequests, fn requests -> requests |> Map.put(correlation_id, request) end)
  end

  def remove_pending_request(correlation_id) do
    Agent.update(PendingRequests, fn requests -> requests |> Map.delete(correlation_id) end)
  end

end
