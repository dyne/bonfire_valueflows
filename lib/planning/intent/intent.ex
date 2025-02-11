defmodule ValueFlows.Planning.Intent do
  use Pointers.Pointable,
    otp_app: :bonfire_valueflows,
    source: "vf_intent",
    table_id: "1NTENTC0V1DBEAN0FFER0RNEED"

  import Bonfire.Common.Repo.Utils, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset


  alias Bonfire.Quantify.Measure

  alias ValueFlows.Knowledge.Action
  alias ValueFlows.Knowledge.ResourceSpecification
  alias ValueFlows.Proposal
  alias ValueFlows.Proposal.ProposedIntent
  alias ValueFlows.EconomicResource
  alias ValueFlows.Process

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:name, :string)
    field(:note, :string)
    belongs_to(:image, Bonfire.Files.Media)

    belongs_to(:provider, ValueFlows.Util.user_or_org_schema())
    belongs_to(:receiver, ValueFlows.Util.user_or_org_schema())

    field(:is_offer, :boolean, virtual: true)
    field(:is_need, :boolean, virtual: true)

    belongs_to(:available_quantity, Measure, on_replace: :nilify)
    belongs_to(:resource_quantity, Measure, on_replace: :nilify)
    belongs_to(:effort_quantity, Measure, on_replace: :nilify)

    field(:has_beginning, :utc_datetime_usec)
    field(:has_end, :utc_datetime_usec)
    field(:has_point_in_time, :utc_datetime_usec)
    field(:due, :utc_datetime_usec)
    field(:finished, :boolean, default: false)

    # array of URI
    field(:resource_classified_as, {:array, :string}, virtual: true)

    belongs_to(:resource_conforms_to, ResourceSpecification)
    belongs_to(:resource_inventoried_as, EconomicResource)

    belongs_to(:at_location, Bonfire.Geolocate.Geolocation)

    belongs_to(:action, Action, type: :string)

    has_many(:published_in, ProposedIntent)
    many_to_many(:published_proposals, Proposal, join_through: ProposedIntent)

    belongs_to(:input_of, Process)
    belongs_to(:output_of, Process)

    # belongs_to(:agreed_in, Agreement)

    belongs_to(:creator, ValueFlows.Util.user_schema())
    belongs_to(:context, Pointers.Pointer)

    # field(:deletable, :boolean) # TODO - virtual field? how is it calculated?

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    timestamps(inserted_at: false)
  end

  @required ~w(name is_public action_id)a
  @cast @required ++
    ~w(note has_beginning has_end has_point_in_time due finished at_location_id is_disabled image_id context_id input_of_id output_of_id)a ++
    ~w(available_quantity_id resource_quantity_id effort_quantity_id resource_conforms_to_id resource_inventoried_as_id provider_id receiver_id)a

  def validate_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.change(
      is_public: true
    )
    |> Changeset.validate_required(@required)
    |> common_changeset(attrs)
  end

  def create_changeset(%{} = creator, attrs) do
    validate_changeset(attrs)
    |> Changeset.change(
      creator_id: creator.id,
    )
  end

  def update_changeset(%__MODULE__{} = intent, attrs) do
    intent
    |> Changeset.cast(attrs, @cast)
    |> common_changeset(attrs)
  end

  def measure_fields do
    [:resource_quantity, :effort_quantity, :available_quantity]
  end

  defp common_changeset(changeset, attrs) do
    changeset
    |> ValueFlows.Util.change_measures(attrs, measure_fields())
    |> change_public()
    |> change_disabled()
    |> datetime_check()
    |> Changeset.foreign_key_constraint(
      :at_location_id,
      name: :vf_intent_at_location_id_fkey
    )
  end

  # Validate datetime mutual exclusivity and requirements.
  # In other words, require one of these combinations to be provided:
  #   * only :has_point_in_time
  #   * only :has_beginning and/or :has_end
  @spec datetime_check(Changeset.t()) :: Changeset.t()
  defp datetime_check(cset) do
    import Changeset, only: [get_change: 2, add_error: 3]

    point = get_change(cset, :has_point_in_time)
    begin = get_change(cset, :has_beginning)
    endd  = get_change(cset, :has_end)

    cond do
      point && begin ->
        msg = "has_point_in_time and has_beginning are mutually exclusive"

        cset
        |> add_error(:has_point_in_time, msg)
        |> add_error(:has_beginning, msg)

      point && endd ->
        msg = "has_point_in_time and has_end are mutually exclusive"

        cset
        |> add_error(:has_point_in_time, msg)
        |> add_error(:has_end, msg)

      point || begin || endd ->
        cset

      true ->
        msg = "has_point_in_time or has_beginning or has_end is requried"

        cset
        |> add_error(:has_beginning, msg)
        |> add_error(:has_end, msg)
        |> add_error(:has_point_in_time, msg)
    end
  end

  def context_module, do: ValueFlows.Planning.Intent.Intents

  def queries_module, do: ValueFlows.Planning.Intent.Queries

  def follow_filters, do: [:default]
end
