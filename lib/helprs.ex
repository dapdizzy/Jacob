defmodule Helpers do
  def ets_exist?(ets_name) do
    case :ets.info(ets_name) do
      :undefined -> false
      _ -> true
    end
  end
end
