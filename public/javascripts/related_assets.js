related_assets = {
  initialize: function() {
    var container = $("#related_assets");
    var searchUrl = container.data("search-url");
    var createUrl = container.data("create-url");
    var list = $("#related_asset_list");

    related_assets.update_headline_badge(list);

    initSearchPicker({
      inputSelector: "#related_asset_search_term",
      resultsSelector: "#related_asset_search_results",
      url: searchUrl,
      loadOnFocus: true,
      renderResults: function(data, results) {
        var found = false;
        data.forEach(function(asset) {
          var item = $("<a>", { href: "#", "class": "related_asset_result" });
          item.append($("<img>", { src: asset.thumb_url, alt: "" }));
          item.append($("<span>").text(asset.name || ""));
          item.bind("click", function() {
            related_assets.attach(asset.id, createUrl, list);
            return false;
          });
          results.append(item);
          found = true;
        });
        return found;
      }
    });

    $(document).on("click", function(e) {
      if (!$(e.target).closest("#related_assets").length) {
        $("#related_asset_search_results").slideUp().empty();
      }
    });

    list.sortable({
      handle: ".related_asset_handle",
      update: function(event, ui) {
        var newPosition = ui.item.index() + 1; // acts_as_list is 1-based; jQuery UI's index() is 0-based
        $.ajax({
          type: "PATCH",
          url: ui.item.data("url"),
          data: "position=" + newPosition
        });
        related_assets.update_headline_badge(list);
      }
    });

    list.on("click", ".related_asset_remove", function() {
      var item = $(this).closest("li");
      $.ajax({
        type: "DELETE",
        url: item.data("url"),
        success: function() {
          item.remove();
          related_assets.update_headline_badge(list);
        }
      });
    });
  },

  update_headline_badge: function(list) {
    list.find(".related_asset_headline_badge").remove();
    var first = list.children("li").first();
    if (first.length) {
      $("<span>", {
        "class": "related_asset_headline_badge",
        "title": "Shown automatically as this page's headline image"
      }).text("Headline").insertBefore(first.find(".related_asset_remove"));
    }
  },

  attach: function(assetId, createUrl, list) {
    $.ajax({
      type: "POST",
      url: createUrl,
      data: "asset_id=" + assetId,
      dataType: "json",
      success: function(related) {
        var item = $($("#related_asset_template").html().trim());
        item.attr("data-url", related.url);
        item.attr("data-large-url", related.large_url);
        item.attr("data-original-url", related.original_url);
        item.attr("data-name", related.name);
        item.find("img").attr("src", related.thumb_url);
        list.append(item);
        list.sortable("refresh");
        related_assets.update_headline_badge(list);
        $("#related_asset_search_term").val("");
        $("#related_asset_search_results").slideUp().empty();
      }
    });
  }
};
