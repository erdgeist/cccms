module CccConventions
  ERFA_PARENT_NAME       = "club/erfas"
  CHAOSTREFF_PARENT_NAME = "club/chaostreffs"

  NODE_KINDS = {
    "top_level" => {
      parent:      -> { Node.root },
      path_prefix: "",
      label:       "Top Level"
    },
    "generic" => {
      label: "Generic",
      hint:  "Can be created anywhere - choose the parent below."
      # no path_prefix - depends on whatever parent gets chosen; see below
    },
    "update" => {
      parent:      -> { Update.find_or_create_parent },
      tags:        ["update"],
      path_prefix: -> { "updates/#{Time.now.year}" },
      label:       "Update",
      hint:        -> { "Automatically created in /updates/#{Time.now.year}/, gets tag \"update\", and inherits the update template." }
    },
    "press_release" => {
      parent:      -> { Update.find_or_create_parent },
      tags:        ["update", "pressemitteilung"],
      path_prefix: -> { "updates/#{Time.now.year}" },
      label:       "Pressemitteilung",
      hint:        -> { "Automatically created in /updates/#{Time.now.year}/, gets tags \"update, pressemitteilung\", and inherits the update template." }
    },
    "erfa" => {
      parent:      -> { Node.find_by_unique_name!(ERFA_PARENT_NAME) },
      tags:        ["erfa-detail"],
      template:    "chapter_detail",
      path_prefix: ERFA_PARENT_NAME,
      label:       "Erfa",
      hint:        "Automatically created under the Erfa-Kreise overview page, gets tag \"erfa-detail\", and uses the chapter detail template."
    },
    "chaostreff" => {
      parent:      -> { Node.find_by_unique_name!(CHAOSTREFF_PARENT_NAME) },
      tags:        ["chaostreff-detail"],
      template:    "chapter_detail",
      path_prefix: CHAOSTREFF_PARENT_NAME,
      label:       "Chaostreff",
      hint:        "Automatically created under the Chaostreffs overview page, gets tag \"chaostreff-detail\", and uses the chapter detail template."
    }
  }.freeze
end
