function hide_all() {
    $('#recent_changes_toggle').attr("class", "unselected");
    $('#my_work_toggle').attr("class", "unselected");
    $('#current_drafts_toggle').attr("class", "unselected");
    $('#admin_sitemap_toggle').attr("class", "unselected");

    $('#current_drafts_table').hide();
    $('#my_work_table').hide();
    $('#recent_changes_table').hide();
    $('#admin_sitemap_table').hide();
}

$(document).ready(function () {
  admin_search.initialize();

  tinymce.init({
    selector: 'textarea.with_editor',
    license_key: 'gpl',
    promotion: false,
    menubar: false,
    plugins: 'code link lists visualblocks',
    toolbar: 'bold italic underline | bullist numlist | link unlink | blocks | code',
    extended_valid_elements: 'aggregate[children|tags|limit|order_by|order_direction|partial|conditions]',
    relative_urls: false,
    entity_encoding: 'raw',
    valid_classes: { '*': '' },
    setup: function(editor) {
      editor.on('init', function() {
        cccms.setup_autosave();
      });
    }
  });

  if ($("#menu_search_term").length != 0) {
    menu_items.initialize_search();
  }

  if ($("#menu_item_list").length != 0) {
    menu_item_sorter.initialize();
  }

  if ($("#metadata").length != 0) {
    meta_data.initialize();
  }

  if ($("#parent_search_term").length != 0) {
    parent_search.initialize_search();
  }

  if ($("#move_to_search_term").length != 0) {
    move_to_search.initialize_search();
  }

  if ($("#rrule_builder").length != 0) {
    rrule_builder.initialize();
  }

  if ($('#recent_changes_toggle').length != 0) {
    hide_all();
    $('#recent_changes_toggle').attr("class", "selected");
    $('#recent_changes_table').show();

    $('#recent_changes_toggle').bind("click", function(){
      hide_all();
      $('#recent_changes_toggle').attr("class", "selected");
      $('#recent_changes_table').show();
      return false;
    });

    $('#my_work_toggle').bind("click", function(){
      hide_all();
      $('#my_work_toggle').attr("class", "selected");
      $('#my_work_table').show();
      return false;
    });

    $('#admin_wizard_my_work').bind("click", function(){
      hide_all();
      $('#my_work_toggle').attr("class", "selected");
      $('#my_work_table').show();
      return false;
    });

    $('#current_drafts_toggle').bind("click", function(){
      hide_all();
      $('#current_drafts_toggle').attr("class", "selected");
      $('#current_drafts_table').show();
      return false;
    });

    $('#admin_sitemap_toggle').bind("click", function(){
      hide_all();
      $('#admin_sitemap_toggle').attr("class", "selected");
      $('#admin_sitemap_table').show();
      return false;
    });

    $('#admin_wizard_create_page').bind("click", function(){
      hide_all();
      $('#admin_sitemap_toggle').attr("class", "selected");
      $('#admin_sitemap_table').show();
      return false;
    });
  }

  jQuery.ajaxSetup({
    'beforeSend': function(xhr) {xhr.setRequestHeader("Accept", "text/javascript");}
  });

  $(document).ajaxSend(function(event, request, settings) {
    if (typeof(AUTH_TOKEN) == "undefined") return;
    // settings.data is a serialized string like "foo=bar&baz=boink" (or null)
    settings.data = settings.data || "";
    settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(AUTH_TOKEN);
  });

});


meta_data = {
  initialize : function() {
    document.getElementById("metadata_details").addEventListener("toggle", function() {
      if (this.open) image_interface.initialize();
    });
  }
};

cccms = {
  setup_autosave : function() {

    var elements = {
      title     : $('#page_title'),
      abstract  : $('#page_abstract'),
      body      : $('#page_body_ifr').contents().find('#tinymce'),
    }

    var page = {
      cached_title    : elements.title.val(),
      cached_abstract : elements.abstract.val(),
      cached_body     : elements.body.html(),

      title_has_changed : function() {
         return (elements.title.val() != this.cached_title)
       },

       abstract_has_changed : function() {
         return (elements.abstract.val() != this.cached_abstract)
       },

       body_has_changed : function() {
         return elements.body.html() != this.cached_body
       }
    }

    jQuery.fn.submitWithAjax = function(options) {
      if (page.title_has_changed() || page.abstract_has_changed() || page.body_has_changed()) {

        page.cached_title      = elements.title.val();
        page.cached_abstract   = elements.abstract.val();
        page.cached_body       = elements.body.html();

        var data = this.serializeArray().filter(function(field) {
          return field.name !== "_method";
        });
        data.push({ name: "_method", value: "put" });

        $.ajax({
          type: "POST",
          url: this.attr("data-autosave-url"),
          data: data,
          error: function(xhr) {
            if (xhr.status === 423) {
              clearInterval(cccms.autosave_timer);
              cccms.report_lock_lost($("#page_editor > form").attr("data-show-url"));
            }
            // any other failure: quietly retried on the next tick
          }
        });

      }
    };

    cccms.autosave_timer = setInterval(function() {
      $("#page_editor > form").submitWithAjax();
    }, 7000);
  },

  report_lock_lost : function(show_url) {
    var $flash = $("#flash");
    if ($flash.length === 0) {
      $flash = $("<div>", { id: "flash" }).insertAfter(".admin_content_spacer");
    }

    var $banner = $("<span>", { "class": "warning" }).text(
      "This page is now locked by someone else — your changes here can no longer be saved. Copy anything you need, then "
    );
    $banner.append($("<a>", { href: show_url }).text("return to the published page"));
    $banner.append(".");

    $flash.html($banner);
  }
}

menu_item_sorter = {

  initialize : function() {
    $("#menu_item_list").sortable({
      axis: 'y',
      items: 'tr',
      handle: 'td.menu_sort_handle',
      placeholder: 'ui-state-highlight',
      start: function(e, ui) {
        menu_item_sorter.placeholder_helper(e,ui);
      },
      stop : function(){
        $.ajax({
          type: "POST",
          url: "/menu_items/0/sort",
          data: $(this).sortable("serialize"),
          dataType: "json",
          success : function(results) {
            alert(results);
          }
        });
      }
    });
  },

  placeholder_helper : function(e,ui) {
    $(".ui-state-highlight").html("<td colspan='100%'></td>");
  }
}

image_interface = {

  initialize : function() {

    $("#image_browser").hide();
    image_interface.initialize_sortable_image_box();
    image_interface.connect_browser_and_box();
    image_interface.set_droppable_behavior();
    image_interface.bind_image_browser_toggle();
  },


  set_droppable_behavior : function() {
    $("ul#image_box").droppable({
      out : function(event, ui) {
        $(ui.draggable).fadeTo("fast", 0.4);

        $(ui.draggable).bind("mouseup", function() {
          $(this).remove();
        });
      },
      over : function(event, ui) {
        $(ui.draggable).fadeTo("fast", 1.0);
        $(ui.draggable).unbind("mouseup");
      }
    });
  },

  connect_browser_and_box : function() {
    $("#image_browser ul li").draggable({
      connectToSortable : 'ul#image_box',
      helper : 'clone',
      revert : 'invalid'
    });
  },

  initialize_sortable_image_box : function() {

    $("ul#image_box").sortable({
      revert  : true,
      update    : function(event, ui) {
        images = $("ul#image_box").sortable("serialize", {attribute : "rel"});

        $.ajax({
          type : "POST",
          url  : "/pages/" + $("ul#image_box").attr("rel") + "/sort_images",
          dataType : "json",
          data : images + "&_method=put",
          success : function() {
          }
        });
      }
    });
  },

  bind_image_browser_toggle : function() {
    $("#image_browser_toggle").bind("click", function(){
      if ($("#image_browser_toggle").attr("class") == "unselected") {
        $("#image_browser_toggle").attr("class", "selected");
        $("#image_browser").show();
      }
      else {
        $("#image_browser_toggle").attr("class", "unselected");
        $("#image_browser").hide();
      }

      return false;
    });
  }
}

rrule_builder = {
  initialize : function() {
    rrule_builder.try_populate_from_rrule($("#event_rrule").val());

    $("input[name='rrule_freq']").bind("change", function() {
      if ($(this).val() === "weekly") { rrule_builder.show_weekly_options(); }
      else { rrule_builder.show_monthly_options(); }
      rrule_builder.sync();
    });
    $("#rrule_monthly_ordinal").bind("change", function() {
      $("#rrule_ordinal_fields").toggle($(this).is(":checked"));
      rrule_builder.sync();
    });
    $("#rrule_exclude_month").bind("change", function() {
      $("#rrule_excluded_month").toggle($(this).is(":checked"));
      rrule_builder.sync();
    });
    $("#rrule_builder input, #rrule_builder select").bind("change", rrule_builder.sync);
  },

  show_weekly_options : function() {
    $("#rrule_weekly_options").show();
    $("#rrule_monthly_options").hide();
  },
  show_monthly_options : function() {
    $("#rrule_weekly_options").hide();
    $("#rrule_monthly_options").show();
  },

  sync : function() {
    var freq = $("input[name='rrule_freq']:checked").val();
    var parts = [];

    if (freq === "weekly") {
      parts.push("FREQ=WEEKLY");
      if ($("#rrule_biweekly").is(":checked")) parts.push("INTERVAL=2");
      var days = [];
      $("input[id^='rrule_byday_']:checked").each(function() {
        days.push($(this).attr("id").replace("rrule_byday_", ""));
      });
      if (days.length > 0) parts.push("BYDAY=" + days.join(","));
    } else {
      parts.push("FREQ=MONTHLY");
      if ($("#rrule_monthly_ordinal").is(":checked")) {
        parts.push("BYDAY=" + $("#rrule_ordinal").val() + $("#rrule_ordinal_day").val());
      }
    }

    if ($("#rrule_exclude_month").is(":checked")) {
      var excluded = parseInt($("#rrule_excluded_month").val(), 10);
      var months = [];
      for (var m = 1; m <= 12; m++) { if (m !== excluded) months.push(m); }
      parts.push("BYMONTH=" + months.join(","));
    }

    $("#event_rrule").val(parts.join(";"));
  },

  try_populate_from_rrule : function(rrule) {
    if (!rrule) return;
    var parts = {};
    rrule.split(";").forEach(function(p) {
      var kv = p.split("=");
      parts[kv[0]] = kv[1];
    });
    if (parts.COUNT || parts.UNTIL) return;

    if (parts.FREQ === "WEEKLY") {
      $("input[name='rrule_freq'][value='weekly']").prop("checked", true);
      rrule_builder.show_weekly_options();
      if (parts.INTERVAL === "2") $("#rrule_biweekly").prop("checked", true);
      if (parts.BYDAY) {
        parts.BYDAY.split(",").forEach(function(code) {
          $("#rrule_byday_" + code).prop("checked", true);
        });
      }
    } else if (parts.FREQ === "MONTHLY") {
      $("input[name='rrule_freq'][value='monthly']").prop("checked", true);
      rrule_builder.show_monthly_options();
      var match = parts.BYDAY && parts.BYDAY.match(/^(-?\d+)([A-Z]{2})$/);
      if (match) {
        $("#rrule_monthly_ordinal").prop("checked", true);
        $("#rrule_ordinal_fields").show();
        $("#rrule_ordinal").val(match[1]);
        $("#rrule_ordinal_day").val(match[2]);
      }
    } else {
      return;
    }

    if (parts.BYMONTH) {
      var included = parts.BYMONTH.split(",").map(function(s) { return parseInt(s, 10); });
      var missing = [];
      for (var m = 1; m <= 12; m++) { if (included.indexOf(m) === -1) missing.push(m); }
      if (missing.length === 1) {
        $("#rrule_exclude_month").prop("checked", true);
        $("#rrule_excluded_month").val(missing[0]).show();
      }
    }
  }
};
