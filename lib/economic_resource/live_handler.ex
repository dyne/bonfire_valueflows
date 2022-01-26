defmodule ValueFlows.EconomicResource.LiveHandler do
  use Bonfire.Web, :live_handler

  alias ValueFlows.EconomicResource
  alias ValueFlows.EconomicResource.EconomicResources


  def handle_event("autocomplete", %{"value"=>search}, socket), do: handle_event("autocomplete", search, socket)
  def handle_event("autocomplete", search, socket) when is_binary(search) do

    user = current_user(socket)
    options = ( EconomicResources.search(user, search) || [] )
              |> Enum.map(&to_tuple/1)
    # IO.inspect(matches)

    {:noreply, socket |> assign_global(economic_resources_autocomplete: options) }
  end


  def handle_event("select", %{"id" => select_resource, "name"=> name} = attrs, socket) when is_binary(select_resource) do
    # IO.inspect(socket)

    selected = {name, select_resource}

    IO.inspect(selected)
    {:noreply, socket |> assign_global(economic_resource_selected: [selected])}
  end

  def to_tuple(resource_spec) do
    {resource_spec.name, resource_spec.id}
  end

end
