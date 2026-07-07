module CccConventions
  ERFA_PARENT_NAME       = "club/erfas"
  CHAOSTREFF_PARENT_NAME = "club/chaostreffs"

  NODE_KINDS = {
    "top_level" => {
      parent:       -> { Node.root },
      parent_match: ->(path) { path == [] },
      path_prefix:  "",
      label:        "Top Level"
    },
    "generic" => {
      parent_match: ->(path) { true },
      label:        "Generic",
      hint:         "Can be created anywhere - choose the parent below."
    },
    "update" => {
      parent:       -> { Update.find_or_create_parent },
      parent_match: ->(path) { path[0] == "updates" && (path.length == 1 || path[1] =~ /\A\d{4}\z/) },
      tags:         ["update"],
      path_prefix:  -> { "updates/#{Time.now.year}" },
      label:        "Update",
      hint:         -> { "Automatically created in /updates/#{Time.now.year}/, gets tag \"update\", and inherits the update template." }
    },
    "press_release" => {
      parent:       -> { Update.find_or_create_parent },
      parent_match: ->(path) { path[0] == "updates" && (path.length == 1 || path[1] =~ /\A\d{4}\z/) },
      tags:         ["update", "pressemitteilung"],
      path_prefix:  -> { "updates/#{Time.now.year}" },
      label:        "Pressemitteilung",
      hint:         -> { "Automatically created in /updates/#{Time.now.year}/, gets tags \"update, pressemitteilung\", and inherits the update template." }
    },
    "erfa" => {
      parent:       -> { Node.find_by_unique_name!(ERFA_PARENT_NAME) },
      parent_match: ->(path) { path == ["club", "erfas"] },
      tags:         ["erfa-detail"],
      template:     "chapter_detail",
      path_prefix:  ERFA_PARENT_NAME,
      label:        "Erfa",
      hint:         "Automatically created under the Erfa-Kreise overview page, gets tag \"erfa-detail\", and uses the chapter detail template."
    },
    "chaostreff" => {
      parent:       -> { Node.find_by_unique_name!(CHAOSTREFF_PARENT_NAME) },
      parent_match: ->(path) { path == ["club", "chaostreffs"] },
      tags:         ["chaostreff-detail"],
      template:     "chapter_detail",
      path_prefix:  CHAOSTREFF_PARENT_NAME,
      label:        "Chaostreff",
      hint:         "Automatically created under the Chaostreffs overview page, gets tag \"chaostreff-detail\", and uses the chapter detail template."
    }
  }.freeze
end
