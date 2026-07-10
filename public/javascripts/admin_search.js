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

    $("#search_term").bind("input", function() {
      if (!$('#search_widget').is(':visible')) return;
      if ($(this).val()) {
        $.ajax({
          type: "GET",
          url: ADMIN_SEARCH_URL,
          data: "search_term=" + $(this).val(),
          dataType: "json",
          success: function(results) {
            admin_search.show_results(results);
          },
          error: function(xhr, status, error) {
            console.log("Ajax error:", status, error, xhr.status, xhr.responseText);
          }
        });
      } else {
        $('#menu_search_results').slideUp();
        $('#menu_search_results').empty();
      }
    });
  },

  display_toggle : function() {
    if ($('#search_widget').is(':visible')) {
      $('#search_widget').fadeOut();
    } else {
      $('#search_widget').fadeIn();
      $('#search_term').focus();
    }
  },

  show_results : function(results) {
    $('#menu_search_results').empty();
    if (results.length) {
      $('#menu_search_results').append(
        "<p class='search_more'>Press Enter to see all results ⏎</p>"
      );
    }
    for (result in results) {
      $('#menu_search_results').append(
        "<p><a href='" + results[result].node_path + "'>" +
          results[result].title +
          "<span class='result_path'>" + results[result].unique_name + "</span>" +
        "</a></p>"
      );
    }
    $('#menu_search_results').slideDown();
  }
};

menu_items = {

  initialize_search : function() {
    $("#menu_search_term").bind("input", function() {
      if ($(this).val()) {
        $.ajax({
          type: "GET",
          url: ADMIN_MENU_SEARCH_URL,
          data: "search_term=" + $(this).val(),
          dataType: "json",
          success : function(results) {
            menu_items.show_results(results);
          }
        });
      }
      else {
        $('#search_results').slideUp();
        $('#search_results').empty();
      }
    });
  },

  show_results : function(results) {
    $("#search_results").empty();
    for (result in results) {
      var link = $(("<a href='#'>"+ results[result].title + "</a>"));
      $(link).bind("click", menu_items.link_closure(results[result]));


      // Sometimes I don't get jquery; wrap() didn't work *sigh*
      // Guess I'll need a book someday or another framework
      var wrapper = $("<div></div>");
      $(wrapper).append(link)

      $("#search_results").append(wrapper);

    }
  },

  link_closure : function(node) {
    var barf = function(){
      $("#menu_item_node_id").val(node.node_id);
      $("#menu_item_path").val("/" + node.unique_name);
      $("#menu_item_title").val(node.title);
      return false;
    }

    return barf;
  }
};

parent_search = {
  initialize_search : function() {
    parent_search.initialize_radio_buttons();

    $("#parent_search_term").bind("input", function() {
      if ($(this).val()) {
        $.ajax({
          type: "GET",
          url: ADMIN_MENU_SEARCH_URL,
          data: "search_term=" + $(this).val(),
          dataType: "json",
          success : function(results) {
            parent_search.show_results(results);
          }
        });
      }
      else {
        $('#search_results').slideUp();
        $('#search_results').empty();
      }
    });

    $("#title").bind("input", function() {
      parent_search.update_resulting_path();
    });

    $("#copy_resulting_path").bind("click", function() {
      var path = $("#resulting_path").text();
      if (path === "—" || !navigator.clipboard) return;
      navigator.clipboard.writeText(path);
    });
  },

  show_results : function(results) {
    $("#search_results").empty();
    var found = false;
    for (result in results) {

      var link = $((
        "<p><a href='#'>" + results[result].title +
          "<span class='result_path'>" + results[result].unique_name + "</span>" +
        "</a></p>"));

      $(link).bind("click", parent_search.link_closure(results[result]));

      $("#search_results").append(link);
      found = true;
    }
    if (found)
      $('#search_results').slideDown();
  },

  link_closure : function(node) {
    var barf = function(){
      $("#parent_search_term").val(node.title);
      $("#parent_id").val(node.node_id).attr("data-unique-name", node.unique_name);
      $('#search_results').slideUp();
      $('#search_results').empty();
      parent_search.update_resulting_path();
      return false;
    }

    return barf;
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
}

move_to_search = {
  initialize_search : function() {
    $("#move_to_search_term").bind("input", function() {move_to_search.do_search($(this))});
  },

  do_search : function(_this) {
    if (_this.val()) {
      $.ajax({
        type: "GET",
        url: ADMIN_MENU_SEARCH_URL,
        data: "search_term=" + _this.val(),
        dataType: "json",
        success : function(results) {
          move_to_search.show_results(results);
        }
      });
    }
    else {
      $('#search_results').slideUp();
      $('#search_results').empty();
    }
  },

  show_results : function(results) {
    $("#search_results").empty();
    var found = false;
    for (result in results) {
      var link = $(("<a href='#'>"+ results[result].title + "</a>"));
      $(link).bind("click", move_to_search.link_closure(results[result]));


      // Sometimes I don't get jquery; wrap() didn't work *sigh*
      // Guess I'll need a book someday or another framework
      var wrapper = $("<div></div>");
      $(wrapper).append(link)

      $("#search_results").append(wrapper);
      found = true;
    }
    if (found)
      $('#search_results').slideDown();
    else
      $('#search_results').slideUp();

  },

  link_closure : function(node) {
    var barf = function(){
      $("#move_to_search_term").val(node.title);
      $("#node_staged_parent_id").val(node.node_id);
      $('#search_results').slideUp();
      $('#search_results').empty();
      return false;
    }

    return barf;
  }
}

event_search = {
  initialize_search : function() {
    $("#event_node_search_term").bind("input", function() {
      if ($(this).val()) {
        $.ajax({
          type: "GET",
          url: ADMIN_MENU_SEARCH_URL,
          data: "search_term=" + $(this).val(),
          dataType: "json",
          success : function(results) {
            event_search.show_results(results);
          }
        });
      }
      else {
        $('#search_results').slideUp();
        $('#search_results').empty();
      }
    });
  },

  show_results : function(results) {
    $("#search_results").empty();
    var found = false;
    for (result in results) {
      var link = $((
        "<p><a href='#'>" + results[result].title +
          "<span class='result_path'>" + results[result].unique_name + "</span>" +
        "</a></p>"));

      $(link).bind("click", event_search.link_closure(results[result]));

      $("#search_results").append(link);
      found = true;
    }
    if (found)
      $('#search_results').slideDown();
    else
      $('#search_results').slideUp();
  },

  link_closure : function(node) {
    var barf = function(){
      $("#event_node_search_term").val(node.title);
      $("#event_node_id").val(node.node_id);
      $('#search_results').slideUp();
      $('#search_results').empty();

      var title_field = $("#event_title");
      if (title_field.val() === "") {
        $("#event_title_hint").text("Using \"" + node.title + "\" from the associated node.");
      }

      return false;
    }
    return barf;
  }
};
