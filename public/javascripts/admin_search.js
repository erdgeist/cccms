admin_search = {
  initialize : function() {
    $(document).bind("keydown", 'Alt+f', function(){
      admin_search.display_toggle();
      return false;
    });

    $(document).bind("keydown", function(e) {
      if (e.key === "Escape" && $('#search_widget').is(':visible')) {
        $('#search_widget').fadeOut();
      }
    });

    $(document).bind("click", function(e) {
      if ($('#search_widget').is(':visible') &&
          !$(e.target).closest('#search_widget').length &&
          !$(e.target).closest('a[onclick*="display_toggle"]').length) {
        $('#search_widget').fadeOut();
      }
    });

    initSearchPicker({
      inputSelector: "#search_term",
      resultsSelector: "#menu_search_results",
      url: ADMIN_SEARCH_URL,
      isActive: function() { return $('#search_widget').is(':visible'); },
      resultsHeaderHtml: "<p class='search_more'>Press Enter to see all results ⏎</p>"
    });
  },

  display_toggle : function() {
    if ($('#search_widget').is(':visible')) {
      $('#search_widget').fadeOut();
    } else {
      $('#search_widget').fadeIn();
      $('#search_term').focus();
    }
  }
};

function initSearchPicker(options) {
  var inputSelector = options.inputSelector;
  var resultsSelector = options.resultsSelector;
  var url = options.url || ADMIN_MENU_SEARCH_URL;
  var onSelect = options.onSelect;
  var isActive = options.isActive;
  var resultsHeaderHtml = options.resultsHeaderHtml;
  var renderResults = options.renderResults;
  var showRestricted = options.showRestricted;
  var loadOnFocus = options.loadOnFocus; // optional, fires an initial search on focus with no term typed yet
  var requestId = 0;
  var timeout;
  var results = $(resultsSelector);

  function runSearch(term) {
    var thisRequest = ++requestId;
    $.ajax({
      type: "GET",
      url: url,
      data: "search_term=" + term,
      dataType: "json",
      success: function(data) {
        if (thisRequest !== requestId) return;
        results.empty();

        var found;
        if (renderResults) {
          found = renderResults(data, results, resultsHeaderHtml);
        } else {
          if (data.length && resultsHeaderHtml) {
            results.append(resultsHeaderHtml);
          }
          found = false;
          for (var i = 0; i < data.length; i++) {
            (function(node) {
              var anchor = $("<a>").attr("href", onSelect ? "#" : node.node_path);
              anchor.append(document.createTextNode(node.title || ""));
              anchor.append($("<span>", { "class": "result_path" }).text(node.unique_name || ""));
              if (showRestricted && node.needs_redaktion) {
                anchor.append($("<span>", { "class": "restricted_result" })
                              .text(ADMIN_STRINGS.needs_redaktion));
              }
              var link = $("<p>").append(anchor);

              if (onSelect) {
                anchor.bind("click", function() {
                  onSelect(node);
                  results.slideUp();
                  results.empty();
                  return false;
                });
              }

              results.append(link);
              found = true;
            })(data[i]);
          }
        }

        if (found) {
          results.slideDown();
        } else {
          results.slideUp();
        }
      },
      error: function(xhr, status, error) {
        console.log("Ajax error:", status, error, xhr.status, xhr.responseText);
      }
    });
  }

  $(inputSelector).bind("input", function() {
    if (isActive && !isActive()) return;

    var term = $(this).val();
    clearTimeout(timeout);

    if (!term) {
      results.slideUp();
      results.empty();
      return;
    }

    timeout = setTimeout(function() { runSearch(term); }, 250);
  });

  if (loadOnFocus) {
    $(inputSelector).bind("focus", function() {
      if (isActive && !isActive()) return;
      if ($(this).val()) return; // the input handler above already covers a real term
      runSearch("");
    });
  }
}

dashboard_search = {
  initialize : function() {
    initSearchPicker({
      inputSelector: "#dashboard_search_term",
      resultsSelector: "#dashboard_search_results",
      url: DASHBOARD_SEARCH_URL,
      resultsHeaderHtml: "<p class='search_more'>Press Enter to see all results ⏎</p>",
      renderResults: function(data, results, resultsHeaderHtml) {
        var found = false;

        if ((data.tags.length || data.nodes.length) && resultsHeaderHtml) {
          results.append(resultsHeaderHtml);
        }

        if (data.tags.length) {
          results.append("<p class='search_group_label'>Tags</p>");
          var tag_row = $("<div class='search_tag_row'></div>");
          data.tags.forEach(function(tag) {
            tag_row.append(
              $("<a>", { "class": "search_tag_pill" }).attr("href", tag.tag_path).text(tag.name || "")
            );
            found = true;
          });
          results.append(tag_row);
        }

        if (data.nodes.length) {
          results.append("<p class='search_group_label'>Pages</p>");
          data.nodes.forEach(function(node) {
            var anchor = $("<a>").attr("href", node.node_path);
            anchor.append(document.createTextNode(node.title || ""));
            anchor.append($("<span>", { "class": "result_path" }).text(node.unique_name || ""));
            results.append($("<p>").append(anchor));
            found = true;
          });
        }

        return found;
      }
    });
  }
};

menu_items = {
  initialize_search : function() {
    initSearchPicker({
      inputSelector: "#menu_search_term",
      resultsSelector: "#menu_item_search_results",
      onSelect: function(node) {
        $("#menu_item_node_id").val(node.node_id);
        $("#menu_item_path").val("/" + node.unique_name);
        $("#menu_item_title").val(node.title);
      }
    });
  }
};

parent_search = {
  initialize_search : function() {
    parent_search.initialize_radio_buttons();

    initSearchPicker({
      inputSelector: "#parent_search_term",
      resultsSelector: "#parent_search_results",
      showRestricted: true,
      onSelect: function(node) {
        $("#parent_search_term").val(node.title);
        $("#parent_id").val(node.node_id).attr("data-unique-name", node.unique_name);
        parent_search.update_resulting_path();
      }
    });

    $("#title").bind("input", function() {
      parent_search.update_resulting_path();
    });
  },

  update_resulting_path : function() {
    var kind  = $("input[name='kind']:checked");
    var title = $("#title").val();

    if (title === "") {
      $("#resulting_path").text("—");
      return;
    }

    var prefix = kind.val() === "generic"
      ? ($("#parent_id").attr("data-unique-name") || "")
      : (kind.attr("data-path-prefix") || "");

    clearTimeout(parent_search.path_timeout);
    parent_search.path_timeout = setTimeout(function() {
        $.get(PARAMETERIZE_PREVIEW_URL, { title: title }, function(slug) {
        $("#resulting_path").text(window.location.origin + "/" + (prefix ? prefix + "/" : "") + slug);
      });
    }, 300);
  },

  initialize_radio_buttons : function() {
    parent_search.sync_parent_field();
    $("input[name='kind']").bind("change", function() {
      parent_search.sync_parent_field();
      parent_search.update_resulting_path();
    });
  },

  sync_parent_field : function() {
    var kind = $("input[name='kind']:checked").val();
    if (kind === "generic") {
      $("#parent_search_field").show();
    } else {
      $("#parent_search_field").hide();
    }
  }
};

move_to_search = {
  initialize_search : function() {
    initSearchPicker({
      inputSelector: "#move_to_search_term",
      resultsSelector: "#move_to_search_results",
      showRestricted: true,
      onSelect: function(node) {
        $("#move_to_search_term").val(node.title);
        $("#page_parent_node_id").val(node.node_id);
      }
    });
  }
};

restore_search = {
  initialize_search : function() {
    initSearchPicker({
      inputSelector: "#restore_search_term",
      resultsSelector: "#restore_search_results",
      showRestricted: true,
      onSelect: function(node) {
        $("#restore_search_term").val(node.title);
        $("#parent_id").val(node.node_id);
      }
    });
  }
};

event_search = {
  initialize_search : function() {
    initSearchPicker({
      inputSelector: "#event_node_search_term",
      resultsSelector: "#event_search_results",
      onSelect: function(node) {
        $("#event_node_search_term").val(node.title);
        $("#event_node_id").val(node.node_id);

        var title_field = $("#event_title");
        if (title_field.val() === "") {
          $("#event_title_hint").text("Using \"" + node.title + "\" from the associated node.");
        }
      }
    });
  }
};

asset_node_search = {
  initialize_search : function() {
    initSearchPicker({
      inputSelector: "#asset_node_search_term",
      resultsSelector: "#asset_node_search_results",
      onSelect: function(node) {
        $("#asset_node_search_term").val(node.title);
        $("#node_id").val(node.node_id);
      }
    });

    $("#asset_node_search_term").bind("input", function() {
      if ($(this).val() === "") { $("#node_id").val(""); }
    });
  }
};
