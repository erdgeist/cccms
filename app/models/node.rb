class Node < ApplicationRecord
  # Mixins and Plugins
  include NestedTree

  # Associations
  has_many    :pages, -> { order("revision ASC") }, :dependent => :destroy

  # Entries where this node is the primary subject (fast-path column).
  # For a *complete* history, including subtree trash/destroy entries
  # recorded at an ancestor, use participated_actions instead.
  has_many    :node_actions, :dependent => :nullify
  has_many    :action_participations, :class_name => "ActionParticipant", :as => :subject
  has_many    :participated_actions, :through => :action_participations, :source => :node_action

  belongs_to  :head,  :class_name => "Page",  :foreign_key => :head_id, optional: true
  belongs_to  :draft, :class_name => "Page",  :foreign_key => :draft_id, optional: true
  # Autosave pages carry no node_id, so has_many :pages does not cover
  # them. This dependent: :destroy is their only cleanup on node destroy.
  belongs_to  :autosave, :class_name => "Page", :foreign_key => :autosave_id, :dependent => :destroy, optional: true

  has_many    :events, :dependent => :destroy
  belongs_to  :lock_owner, :class_name => "User", :foreign_key => :locking_user_id, optional: true

  # Callbacks
  after_create   :initialize_empty_page
  before_save    :check_for_changed_slug
  after_save     :update_unique_names_of_children
  before_destroy :refuse_destroy_with_children
  before_destroy :refuse_destroying_trash_node

  # Validations
  validates_length_of     :slug, :within => 1..255,    :unless => -> { parent_id.nil? || slug.blank? }
  validates_presence_of   :slug,                       :unless => -> { parent_id.nil? }
  validates_uniqueness_of :slug, :scope => :parent_id, :unless => -> { parent_id.nil? }
  validates_presence_of   :parent_id,                  :unless => -> { Node.root.nil? }
  validates_format_of     :slug, :with => /\A[A-Za-z0-9][A-Za-z0-9_-]*\z/,
                          :unless => -> { parent_id.nil? || slug.blank? }

  validate :reserved_slug_stays_reserved
  validate :no_head_inside_trash
  validates :default_template_name,
            :inclusion   => { :in => ->(_) { Page.custom_templates } },
            :allow_blank => true,
            :if          => :default_template_name_changed?

  # Everything outside the Trash subtree, the Trash node included.
  # Relies on unique_name being authoritative for tree position.
  # The same trust public routing places in it.
  scope :not_in_trash, -> {
    where.not(:unique_name => CccConventions::TRASH_SLUG)
      .where("unique_name NOT LIKE ?", "#{CccConventions::TRASH_SLUG}/%")
  }

  # Class methods

  # Returns a page for a given node. If no revision is supplied, it returns
  # the last / current one. If a specific revision number is supplied, the
  # corresponding revision of that page is returned. Get the current / latest
  # revision with -1. It raises an Argument error if the revision is not a
  # Fixnum
  def self.find_page path, revision = -1
    unless revision.is_a?(Integer)
      raise ArgumentError, "revision must be a Integer"
    end

    node = Node.find_by_unique_name(path)

    if node
      case revision
      when -1
        return node.head
      else
        return node.pages.find_by_revision( revision )
      end
    end

    nil
  end

  # The Trash container node. Lazily self-creating and idempotent, so
  # every environment acquires it on first touch.
  # Never call from validations. the positional predicates below
  # exist for that.
  def self.trash
    root.children.find_by(:slug => CccConventions::TRASH_SLUG) ||
      root.children.create!(:slug => CccConventions::TRASH_SLUG).tap do |node|
        Globalize.with_locale(I18n.default_locale) do
          node.draft.update!(:title => "Trash")
        end
      end
  end

  # Instance Methods

  # Acquires (or reaffirms) the editing lock without creating a draft or
  # an autosave, both are now deferred until there is real content to
  # hold.
  def lock_for_editing! current_user
    if self.lock_owner.nil? || self.lock_owner == current_user
      lock_for! current_user
      if self.draft
        self.draft.user = current_user if self.draft.user.nil?
        self.draft.editor = current_user
        self.draft.save!
      end
      self
    else
      raise(
        LockedByAnotherUser,
        "Page is locked by another user who is working on it! " \
        "Last modification: #{(self.autosave || self.draft || self.head).updated_at.to_fs(:db)}"
      )
    end
  end

  def ensure_autosave! current_user
    assert_locked_by! current_user
    unless self.autosave
      self.autosave = Page.create!(:editor => current_user)
      self.autosave.clone_attributes_from(self.draft || self.head) if self.draft || self.head
      self.save!
    end
    self.autosave
  end

  def autosave! attributes, current_user
    ensure_autosave!(current_user)
    attributes = attributes.except(:slug, "slug") if attributes[:slug].blank? && attributes["slug"].blank?
    self.autosave.assign_attributes(attributes)
    self.autosave.save!
    self.autosave
  end

  # Promotes the current autosave into the draft (creating the draft if
  # none exists yet) and destroys the autosave afterward. This is what
  # the explicit "Save" action does; it never creates a new revision,
  # same as any other in-place draft edit. The new draft is created via
  # self.pages.create! rather than by repointing the autosave's own
  # node_id, because acts_as_list assigns the revision number at create
  # time, scoped to node_id, a page created with node_id nil and
  # reassigned afterward would carry a wrong or missing revision number.
  def save_draft! current_user
    assert_locked_by! current_user
    return unless self.autosave

    if self.draft
      preserved_published_at = self.draft.published_at
      self.draft.clone_attributes_from self.autosave
      self.draft.published_at = preserved_published_at
      self.draft.user_id = self.autosave.user_id if self.autosave.user_id
      self.draft.editor  = current_user
      self.draft.save!
    else
      empty_page = self.pages.create!
      empty_page.clone_attributes_from self.autosave
      empty_page.user         = self.autosave.user_id ? self.autosave.user : (self.head ? self.head.user : current_user)
      empty_page.editor       = current_user
      empty_page.published_at = self.head.published_at if self.head
      empty_page.save!
      self.draft = empty_page
      self.save!
    end

    self.autosave.destroy
    self.autosave_id = nil
    self.save!
    self.draft.reload
  end

  def resolve_page_reference ref
    case ref.to_s
    when "head" then head
    when "draft" then draft
    when "autosave" then autosave
    else pages.find_by_revision(ref)
    end
  end

  # Which layer-pairs are meaningful to compare right now, given this
  # node's actual state. Head vs autosave only shows up when no draft
  # sits between them, with a draft present, autosave is compared
  # against the draft, never past it straight to head.
  def available_layer_pairs
    pairs = []
    pairs << [:head, :draft]     if head && draft
    pairs << [:draft, :autosave] if draft && autosave
    pairs << [:head, :autosave]  if head && autosave && !draft
    pairs
  end

  def create_new_draft user
    empty_page        = self.pages.create!
    empty_page.user   = (self.head ? self.head.user : user)
    empty_page.editor = user
    empty_page.save

    empty_page.clone_attributes_from self.head

    self.draft = empty_page
    self.save
    self.draft.reload
  end

  # Discards exactly the topmost non-empty layer: autosave if present,
  # else draft, and reveals whatever's beneath it. Releases the lock
  # only once nothing is left to protect (no draft survives); leaves it
  # alone whenever a draft remains, since #edit still has real content
  # open.
  def revert! current_user
    assert_locked_by! current_user

    if self.autosave
      self.autosave.destroy
      self.autosave_id = nil
      self.save!
      NodeAction.record!(:node => self, :user => current_user, :action => "discard_autosave")
    elsif self.draft && self.head
      self.draft.destroy
      self.draft_id = nil
      self.save!
      NodeAction.record!(:node => self, :user => current_user, :action => "destroy_draft")
    end

    self.unlock! unless self.draft
    self.reload
  end

  def publish_draft! current_user = nil
    # Return nil if nothing to publish
    return nil unless self.draft

    guard_live_change!(current_user, :target_path => prospective_unique_name)

    if in_trash? || trash_node?
      errors.add(:base, :publish_in_trash)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    path_before = self.unique_name

    ActiveRecord::Base.transaction do
      if self.draft
        outgoing_head = self.head
        self.head = self.draft
        self.head.published_at ||= Time.now
        self.head.save!
        self.draft = nil

        NodeAction.record!(:node => self,
                            :participants => [self] + NodeAction.changed_assets(outgoing_head, self.head),
                            :page => self.head, :user => current_user,
                            :action => "publish", :via => "draft",
                            **NodeAction.head_diff(outgoing_head, self.head))
      end

      if self.head.slug.present? && self.head.slug != slug
        self.slug = self.head.slug
      end

      self.external_url = self.head.external_url

      if self.head.parent_node_id && self.head.parent_node_id != parent_id
        new_parent = Node.find_by(:id => self.head.parent_node_id)

        unless new_parent
          errors.add(:base, :move_target_missing)
          raise ActiveRecord::RecordInvalid.new(self)
        end

        if new_parent == self || self.descendants.include?(new_parent) ||
           new_parent.trash_node? || new_parent.in_trash?
          errors.add(:base, :move_under_self)
          raise ActiveRecord::RecordInvalid.new(self)
        end

        self.save!
        self.move_to_child_of(new_parent)
      else
        raise ActiveRecord::RecordInvalid.new(self) unless self.save
      end

      self.reload
      self.update_unique_name
      self.send(:update_unique_names_of_children)
      if self.unique_name != path_before
        NodeAction.record!(:node => self, :user => current_user, :action => "move",
                            :path => { "from" => path_before, "to" => self.unique_name })
      end
      self.unlock!
      self
    end
  end

  def restore_revision! revision, current_user = nil
    page = self.pages.find_by_revision(revision)
    return nil unless page

    ActiveRecord::Base.transaction do
      outgoing_head = self.head
      self.head = page
      self.save!

      NodeAction.record!(:node => self,
                          :participants => [self] + NodeAction.changed_assets(outgoing_head, page),
                          :page => page, :user => current_user,
                          :action => "publish", :via => "revision",
                          **NodeAction.head_diff(outgoing_head, page))
      self
    end
  end


  # Moves this node and its subtree into the Trash. Demotes every head
  # in the subtree first (aggregators and search operate on heads
  # regardless of tree position); where a node has no draft, the former
  # head becomes its draft so content stays editable and restorable,
  # otherwise the former head remains a plain revision. One log entry,
  # at the root, carrying the leaving-public-view snapshot.
  def trash! current_user = nil
    return nil if in_trash?

    guard_live_change!(current_user)

    if trash_node?
      errors.add(:base, :trash_the_trash)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    ActiveRecord::Base.transaction do
      path_before        = unique_name
      was_published      = head_id.present?
      final_published_at = head&.published_at

      subtree = [self] + descendants.to_a
      demoted_nodes = subtree.select do |node|
        next false unless node.head_id
        former        = node.head
        node.head     = nil
        node.draft_id = former.id if node.draft_id.nil?
        node.save!
        true
      end

      self.reload
      move_to_child_of(Node.trash)
      self.reload
      update_unique_name
      send(:update_unique_names_of_children)
      unlock!

      metadata = { :path => { "from" => path_before, "to" => unique_name } }
      metadata[:was_published]      = true if was_published
      metadata[:final_published_at] = final_published_at.iso8601 if final_published_at
      metadata[:demoted_heads]      = demoted_nodes.size if demoted_nodes.any?

      NodeAction.record!(:participants => subtree, :user => current_user,
                          :action => "trash", **metadata)
      self
    end
  end

  # Returns the node to the living tree under a chosen parent. The
  # subtree comes back exactly as it sits in the Trash: all drafts,
  # nothing published. Republication is a separate, witnessed act
  # per node.
  def restore_from_trash! current_user = nil
    return nil unless in_trash?

    target = (draft || head)&.parent_node_id
    new_parent = target ? Node.find_by(:id => target) : nil

    if new_parent.nil? || new_parent == self || descendants.include?(new_parent) ||
       new_parent.trash_node? || new_parent.in_trash?
      errors.add(:base, :restore_target_invalid)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    guard_live_change!(current_user,
                       :target_path => [new_parent.unique_name.presence, slug].compact.join("/"))

    ActiveRecord::Base.transaction do
      path_before = unique_name
      move_to_child_of(new_parent)
      self.reload
      update_unique_name
      send(:update_unique_names_of_children)

      NodeAction.record!(:node => self, :user => current_user, :action => "restore_from_trash",
                          :path => { "from" => path_before, "to" => unique_name })
      self
    end
  end

  # Final deletion, only from inside the Trash. Removes the whole
  # subtree, deepest first, each node through a real destroy! so every
  # per-node cascade runs (the categorical difference from the old
  # delete_all nuke). refuse_destroy_with_children on bare destroy is
  # untouched
  # One log entry at the root, per the subtree rule, written before the
  # rows die.
  def destroy_from_trash! current_user = nil
    guard_live_change!(current_user)

    unless in_trash?
      errors.add(:base, :destroy_outside_trash)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    ActiveRecord::Base.transaction do
      doomed = self_and_descendants_ordered_with_level
                 .sort_by { |_, level| -level }
                 .map(&:first)

      metadata = { :path => unique_name }
      metadata[:destroyed_descendants] = doomed.size - 1 if doomed.size > 1

      NodeAction.record!(:participants => doomed, :user => current_user,
                          :action => "destroy", **metadata)
      doomed.each(&:destroy!)
    end
  end

  # The most recent trash entry. Its path.from is the restore hint.
  def last_trash_entry
    node_actions.where(:action => "trash").order(:occurred_at => :desc, :id => :desc).first
  end

  # The node's pre-trash parent, if a living node still answers to
  # that path. Nil when the parent was itself trashed (its unique_name
  # changed) or deleted; a different node that has since taken over
  # the path is a legitimate suggestion.
  def suggested_restore_parent
    from = last_trash_entry&.metadata&.dig("path", "from")
    return nil unless from

    parent_path = from.rpartition("/").first
    return Node.root if parent_path.empty?

    candidate = Node.find_by(:unique_name => parent_path)
    candidate unless candidate.nil? || candidate.in_trash? || candidate.trash_node?
  end

  # returns an array with all parts of a unique_name rather than a string
  def unique_path
    unique_name.to_s.split("/")
  end

  # returns array with pages up to root excluding root
  def path_to_root
    parent.nil? ? [slug] : parent.path_to_root.push(slug)
  end

  def computed_unique_name
    path_to_root[1..-1].join("/") # excluding root
  end

  def current_unique_name
    self.unique_name = computed_unique_name
  end

  def update_unique_name
    current_unique_name
    self.save
  end

  def locked?
    !self.lock_owner.nil?
  end

  def unlock!
    if self.lock_owner
      self.lock_owner = nil
      self.save
      self
    end
  end

  # Attaches an asset to the node's draft, creating one from the head if
  # none exists.
  #
  # Refuses when an autosave exists: it predates this attach and would
  # overwrite the draft at save_draft!, silently dropping the join.
  # Refuses when someone else holds the lock, so an editor's work is not
  # altered under them.
  #
  # Returns { :attached => n, :already => n, :draft_created => bool,
  #           :headline => nil | :set | :kept_existing | :not_eligible }
  def attach_asset! asset, user:, headline: false
    if in_trash? || trash_node?
      errors.add(:base, :attach_in_trash)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    if lock_owner && lock_owner != user
      raise(
        LockedByAnotherUser,
        "Page is locked by another user who is working on it! " \
        "Last modification: #{(self.autosave || self.draft || self.head).updated_at.to_fs(:db)}"
      )
    end

    if autosave
      errors.add(:base, :attach_with_autosave)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    source = draft || head
    if source && source.related_assets.exists?(:asset_id => asset.id)
      return { :attached      => 0,
               :already       => 1,
               :draft_created => false,
               :headline      => nil }
    end

    draft_created = draft.nil?

    ActiveRecord::Base.transaction do
      create_new_draft(user) if draft_created
      page = draft.reload

      headline_state =
        if headline
          if !(asset.image? || asset.pdf?)
            :not_eligible
          elsif page.headline_asset.present?
            :kept_existing
          else
            :set
          end
        end

      page.related_assets.create!(:asset => asset, :headline => headline_state == :set)

      { :attached      => 1,
        :already       => 0,
        :draft_created => draft_created,
        :headline      => headline_state }
    end
  end

  def title
    editable_page&.title
  end

  def update_unique_names?
    !children.empty? && !children.first.path_to_root.include?(self.slug)
  end

  def head?
    head_id
  end

  def update?
    unique_path.length == 3 && unique_path[0] == "updates"
  end

  def editable_page
    autosave || draft || head
  end

  def trash_node?
    parent&.root? && slug == CccConventions::TRASH_SLUG
  end

  # Inside the Trash subtree. False for the Trash node itself.
  def in_trash?
    current = parent
    while current
      return true if current.trash_node?
      current = current.parent
    end
    false
  end

  def self.restricted_path? name
    name = name.to_s
    return false if name.empty?

    CccConventions::RESTRICTED_SUBTREES.any? do |prefix|
      name == prefix || name.start_with?("#{prefix}/")
    end
  end

  def restricted?
    root? || self.class.restricted_path?(unique_name)
  end

  # Falls back to the live address when the draft records none.
  def prospective_unique_name
    (draft || head)&.prospective_unique_name || unique_name
  end

  # Returns immutable node id for all new nodes so that the atom feed entry ids
  # stay the same eventhough the slug or positions changes.
  # Can be removed after a year or so ;)
  def feed_id
    new_id_format_date = "2009-11-14".to_time
    self.created_at < new_id_format_date ? unique_path : id
  end

  # Full-text search across all locale translations using PostgreSQL tsvector.
  # Uses 'simple' dictionary (no stemming, no stopwords) so queries work
  # across German and English content without language detection.
  def self.search(term, _ = {})
    joins(head: :translations)
      .where("page_translations.search_vector @@ plainto_tsquery('simple', ?)", term)
      .distinct
  end

  # This one is for admin-only views, where finding a draft is the point.
  # Substring match on whichever of head/draft is present.
  def self.editor_search(term)
    words = term.to_s.split(/\s+/).reject(&:blank?)
    return none if words.empty?

    conditions = []
    binds = {}

    words.each_with_index do |word, i|
      key = "term#{i}"
      binds[key.to_sym] = "%#{sanitize_sql_like(word)}%"
      conditions << "(head_translations.title ILIKE :#{key} OR head_translations.abstract ILIKE :#{key} " \
                    "OR draft_translations.title ILIKE :#{key} OR draft_translations.abstract ILIKE :#{key})"
    end

    joins("LEFT JOIN page_translations head_translations ON head_translations.page_id = nodes.head_id")
      .joins("LEFT JOIN page_translations draft_translations ON draft_translations.page_id = nodes.draft_id")
      .where(conditions.join(" AND "), binds)
      .distinct
  end

  # Nodes carrying unfinished work: a draft, an autosave, or a lock with
  # neither behind it
  def self.work_in_progress(current_user_id: nil)
    scope = where("draft_id IS NOT NULL OR autosave_id IS NOT NULL OR locking_user_id IS NOT NULL")
              .not_in_trash
    return scope.order("nodes.updated_at ASC") unless current_user_id

    scope.order(
      Arel.sql(sanitize_sql_array(["CASE WHEN locking_user_id = ? THEN 0 ELSE 1 END, nodes.updated_at ASC", current_user_id]))
    )
  end

  def embargoed?
    head&.published_at.present? && head.published_at > Time.zone.now
  end

  # Nodes are never destroyed recursively
  # Descendants must be removed or reparented individually first.
  # The Trash feature will be the ordinary path to deletion.
  def refuse_destroy_with_children
    return unless children.exists?
    errors.add(:base, :has_children)
    throw :abort
  end

  protected
    def lock_for! current_user
      self.lock_owner = current_user
      self.save
    end

    def assert_locked_by! current_user
      return if self.lock_owner == current_user
      raise(
        LockedByAnotherUser,
        "Page is locked by another user who is working on it! " \
        "Last modification: #{(self.autosave || self.draft || self.head).updated_at.to_fs(:db)}"
      )
    end

    # Creates an empty page and associates it to the given node. This means
    # freshly created node has an empty draft. A user can create nodes as he
    # wants to which will not appear on the public page until the author edits
    # that draft and publishes it.
    def initialize_empty_page
      if self.pages.empty?
        self.draft = self.pages.create!(:slug => self.slug, :parent_node_id => self.parent_id)
        self.save
      end
    end

    def check_for_changed_slug
      if parent and changed.include? "slug"
        self.unique_name = current_unique_name
      end
    end

    # Watch out recursion ahead! update_unique_name itself triggers this
    # after_save callback which invokes update_unique_name on its children.
    # Hopefully until no childrens occur
    #
    # Queries parent_id directly rather than the NestedTree#children
    # association out of habit from the old awesome_nested_set-avoidance
    # workaround - no longer strictly necessary now that children is
    # equally safe, but left as-is since it already works correctly.
    def update_unique_names_of_children
      unless root?
        Node.where(:parent_id => self.id).each do |child|
          child.reload
          child.update_unique_name
          child.send(:update_unique_names_of_children)
        end
      end
    end

  private

    def guard_live_change! user, target_path: nil
      return if user.nil?
      return if user.may_change_live?(self) && user.may_change_live_at?(target_path)

      errors.add(:base, :not_permitted)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    def reserved_slug_stays_reserved
      if parent&.root? && !trash_node_already_me?
        errors.add(:slug, :reserved_for_trash) if slug == CccConventions::TRASH_SLUG
      end

      if persisted? && slug_was == CccConventions::TRASH_SLUG && Node.find(id).trash_node?
        errors.add(:slug, :trash_immutable) if slug_changed?
        errors.add(:parent_id, :trash_immutable) if parent_id_changed?
      end
    end

    def trash_node_already_me?
      existing = Node.root&.children&.find_by(:slug => CccConventions::TRASH_SLUG)
      existing.nil? || existing.id == id
    end

    def no_head_inside_trash
      return unless head_id.present?
      errors.add(:head_id, :inside_trash) if in_trash? || trash_node?
    end

    def refuse_destroying_trash_node
      return unless trash_node?
      errors.add(:base, :trash_undeletable)
      throw :abort
    end
end
