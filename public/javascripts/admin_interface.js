$(document).ready(function () {
  admin_search.initialize();

  tinymce.init({
    selector: 'textarea.with_editor',
    license_key: 'gpl',
    promotion: false,
    menubar: false,
    plugins: 'code link lists visualblocks',
    toolbar: 'bold italic underline | bullist numlist | link unlink | insertpageimage | blocks | code',
    extended_valid_elements: 'aggregate[children|tags|limit|order_by|order_direction|partial|conditions],a[href|target|rel|class|data-gallery],img[class|src|alt|title|width|height|style|border]',
    relative_urls: false,
    entity_encoding: 'raw',
    content_style: '.inline-image--full { width: 100%; margin: 1rem 0; } .inline-image--half { width: 48%; margin-bottom: 1rem; } .inline-image--left { float: left; margin-right: 1rem; } .inline-image--right { float: right; margin-left: 1rem; }',
    valid_classes: {
      '*': '',
      'img': 'inline-image inline-image--full inline-image--half inline-image--left inline-image--right',
      'a': 'glightbox'
    },
    setup: function(editor) {
      editor.on('init', function() {
        cccms.setup_autosave();
      });

      editor.ui.registry.addButton('insertpageimage', {
        icon: 'image',
        text: 'Insert image',
        tooltip: "Insert one of this page's attached images",
        onAction: function() {
          cccms.inline_images.open(editor);
        }
      });
    }
  });

  if ($("#dashboard_search_term").length != 0) {
    dashboard_search.initialize();
  }

  if ($("#menu_search_term").length != 0) {
    menu_items.initialize_search();
  }

  if ($("#menu_item_list").length != 0) {
    menu_item_sorter.initialize();
  }

  if ($("#parent_search_term").length != 0) {
    parent_search.initialize_search();
  }

  if ($("#move_to_search_term").length != 0) {
    move_to_search.initialize_search();
  }

  if ($("#restore_search_term").length != 0) {
    restore_search.initialize_search();
  }

  if ($("#event_node_search_term").length != 0) {
    event_search.initialize_search();
  }

  if ($("#related_asset_search_term").length != 0) {
    related_assets.initialize();
  }

  if ($("#asset_node_search_term").length != 0) {
    asset_node_search.initialize_search();
  }

  if ($("#rrule_builder").length != 0) {
    rrule_builder.initialize();
  }

  if ($("#preview_panel").length != 0) {
    cccms.preview.initialize();
  }

  var metadata_details = document.getElementById('metadata_details');
  if (metadata_details) {
    var desktop_mq = window.matchMedia('(min-width: 1016px)');
    var sync_metadata = function() { metadata_details.open = desktop_mq.matches; };
    sync_metadata();
    desktop_mq.addEventListener('change', sync_metadata);
  }

  var dropzone = document.getElementById('asset_dropzone');
  if (dropzone) {
    var input = dropzone.querySelector('input[type=file]');

    // Without these, a drop that misses the zone navigates the browser
    // to the file, losing the half-filled form.
    ['dragover', 'drop'].forEach(function(ev) {
      window.addEventListener(ev, function(e) { e.preventDefault(); });
    });

    ['dragenter', 'dragover'].forEach(function(ev) {
      dropzone.addEventListener(ev, function(e) {
        e.preventDefault(); dropzone.classList.add('dragging');
      });
    });
    ['dragleave', 'drop'].forEach(function(ev) {
      dropzone.addEventListener(ev, function(e) {
        e.preventDefault(); dropzone.classList.remove('dragging');
      });
    });

    dropzone.addEventListener('drop', function(e) {
      if (!e.dataTransfer.files.length) return;
      var dt = new DataTransfer();
      dt.items.add(e.dataTransfer.files[0]);
      input.files = dt.files;
      input.dispatchEvent(new Event('change', { bubbles: true }));
    });

    input.addEventListener('change', function() {
      var name_field = document.getElementById('asset_name');
      if (input.files.length && name_field && name_field.value === '') {
        name_field.value = input.files[0].name.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ');
      }
    });
  }


  jQuery.ajaxSetup({
    'beforeSend': function(xhr) {xhr.setRequestHeader("Accept", "text/javascript");}
  });

  $(document).ajaxSend(function(event, request, settings) {
    var meta = document.querySelector("meta[name='csrf-token']");
    if (meta) request.setRequestHeader("X-CSRF-Token", meta.content);
  });

  document.addEventListener('click', function (event) {
    var button = event.target.closest('.copy_button');
    if (!button) return;

    var text = button.dataset.copyUrl;
    if (text === undefined && button.dataset.copyTarget) {
      var target = document.querySelector(button.dataset.copyTarget);
      text = target ? target.textContent : undefined;
    }

    if (!text || text === '—' || !navigator.clipboard) return;

    navigator.clipboard.writeText(text).then(function () {
      var label = button.querySelector('.copy_button_label');
      if (!label) return;
      var original = label.textContent;
      label.textContent = 'Copied!';
      setTimeout(function () { label.textContent = original; }, 1500);
    });
  });

});


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
      options = options || {};
      if (options.force || page.title_has_changed() || page.abstract_has_changed() || page.body_has_changed()) {

        elements.body.find('a.glightbox').each(function() {
          if ($(this).find('img').length === 0) { $(this).remove(); }
        });

        tinymce.triggerSave();
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
          success: function() {
            cccms.preview.refresh_if_open();
          },
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
  },

  preview : {
    is_open : false,

    initialize : function() {
      var $panel  = $('#preview_panel');
      var $toggle = $('#preview_toggle');
      var $force  = $('#preview_force_render');

      $toggle.on('click', function() {
        cccms.preview.is_open = !cccms.preview.is_open;
        $panel.toggle(cccms.preview.is_open);
        $force.toggle(cccms.preview.is_open);
        $toggle.attr('aria-pressed', cccms.preview.is_open);
        if (cccms.preview.is_open) cccms.preview.refresh();
      });

      $force.on('click', function() {
        $("#page_editor > form").submitWithAjax({ force: true });
      });
    },

    refresh : function() {
      var $iframe = $('#live_preview_iframe');
      if ($iframe.length === 0) return;
      var base = $iframe.data('src');
      $iframe.attr('src', base + (base.indexOf('?') === -1 ? '?' : '&') + '_t=' + Date.now());
    },

    refresh_if_open : function() {
      if (cccms.preview.is_open) cccms.preview.refresh();
    }
  },

  inline_images: {
    ensure_overlay: function() {
      if ($('#inline_image_picker').length) return;

      var overlay = $(
        '<div id="inline_image_picker" style="display:none">' +
          '<div id="inline_image_picker_grid"></div>' +
          '<div id="inline_image_picker_actions">' +
            '<button type="button" data-placement="full">Insert full width</button>' +
            '<button type="button" data-placement="left">Insert, align left</button>' +
            '<button type="button" data-placement="right">Insert, align right</button>' +
            '<button type="button" id="inline_image_picker_cancel">Cancel</button>' +
          '</div>' +
        '</div>'
      );
      $('body').append(overlay);

      overlay.on('click', '#inline_image_picker_grid img', function() {
        overlay.find('#inline_image_picker_grid img').removeClass('selected');
        $(this).addClass('selected');
        cccms.inline_images.selected_index = $(this).data('index');
      });

      overlay.on('click', '[data-placement]', function() {
        cccms.inline_images.insert($(this).data('placement'));
      });

      overlay.on('click', '#inline_image_picker_cancel', function() {
        overlay.hide();
      });
    },

    open: function(editor) {
      cccms.inline_images.ensure_overlay();
      cccms.inline_images.editor = editor;

      var showUrl = $("#page_editor > form").attr("data-show-url") || "";
      var match = showUrl.match(/(\d+)$/);
      cccms.inline_images.node_id = match ? match[1] : "";

      var items = $('#related_asset_list li').map(function() {
        return {
          id: $(this).data('asset-id'),
          thumb: $(this).find('img').attr('src'),
          large: $(this).data('large-url'),
          original: $(this).data('original-url'),
          name: $(this).data('name'),
          hasCredit: $(this).data('has-credit') === true,
          headline: $(this).data('headline') === true
        };
      }).get();
      cccms.inline_images.items = items;

    var grid = $('#inline_image_picker_grid').empty();
      if (items.length === 0) {
        grid.append('<p>No images are attached to this page yet -- attach one from the Images section first.</p>');
        cccms.inline_images.selected_index = null;
      } else {
        items.forEach(function(item, i) {
          var wrapper = $('<div class="inline_image_picker_item"></div>');
          wrapper.append($('<img>').attr('src', item.thumb).attr('data-index', i));
          if (item.headline) {
            wrapper.append($('<span>', { "class": "inline_image_picker_headline_badge" }).text("Headline"));
          }
          grid.append(wrapper);
        });
        cccms.inline_images.selected_index = 0;
        grid.find('img').first().addClass('selected');
      }

      $('#inline_image_picker').show();
    },

    escape_attr: function(str) {
      return String(str || '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    },

    insert: function(placement) {
      var item = cccms.inline_images.items[cccms.inline_images.selected_index];
      if (!item) return;

      var classes = placement === 'full'
        ? 'inline-image inline-image--full'
        : 'inline-image inline-image--half inline-image--' + placement;

      var esc = cccms.inline_images.escape_attr;
      var titleForGlightbox = (item.name || '').replace(/;/g, ',');
      var glightboxOpts = 'title: ' + esc(titleForGlightbox) +
        (item.hasCredit ? '; description: #credit_for_asset_' + esc(item.id) : '') + ';';
      var html = '<a href="' + esc(item.original) + '" class="glightbox" data-gallery="page-' + esc(cccms.inline_images.node_id) + '"' +
                 ' data-glightbox="' + glightboxOpts + '">' +
                 '<img src="' + esc(item.large) + '" class="' + classes + '" alt="' + esc(item.name) + '"></a>';

      cccms.inline_images.editor.insertContent(html);
      $('#inline_image_picker').hide();
    }
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
      rrule_builder.toggle_custom_ordinal_fields();
      rrule_builder.sync();
    });
    $("#rrule_ordinal").bind("change", rrule_builder.toggle_custom_ordinal_fields);
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

  toggle_custom_ordinal_fields : function() {
    $("#rrule_custom_ordinal_fields").toggle(
      $("#rrule_monthly_ordinal").is(":checked") && $("#rrule_ordinal").val() === "custom"
    );
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
        var ordinal = $("#rrule_ordinal").val();
        if (ordinal === "custom") {
          var customDays = [];
          $("input[id^='rrule_custom_ordinal_']:checked").each(function() {
            customDays.push($(this).attr("id").replace("rrule_custom_ordinal_", "") + $("#rrule_ordinal_day").val());
          });
          if (customDays.length > 0) parts.push("BYDAY=" + customDays.join(","));
        } else {
          parts.push("BYDAY=" + ordinal + $("#rrule_ordinal_day").val());
        }
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
      var ordinalDays = parts.BYDAY && parts.BYDAY.split(",");
      var customOrdinalDay = null;
      var customOrdinals = [];
      var customOrdinalsValid = ordinalDays && ordinalDays.length > 0;
      if (customOrdinalsValid) {
        ordinalDays.forEach(function(value) {
          var customMatch = value.match(/^([1-5])([A-Z]{2})$/);
          if (!customMatch || (customOrdinalDay && customOrdinalDay !== customMatch[2])) {
            customOrdinalsValid = false;
            return;
          }
          customOrdinalDay = customMatch[2];
          customOrdinals.push(customMatch[1]);
        });
      }

      var match = parts.BYDAY && parts.BYDAY.match(/^(-?\d+)([A-Z]{2})$/);
      if (customOrdinalsValid && (customOrdinals.length > 1 || customOrdinals[0] === "5")) {
        $("#rrule_monthly_ordinal").prop("checked", true);
        $("#rrule_ordinal_fields").show();
        $("#rrule_ordinal").val("custom");
        $("#rrule_ordinal_day").val(customOrdinalDay);
        customOrdinals.forEach(function(ordinal) {
          $("#rrule_custom_ordinal_" + ordinal).prop("checked", true);
        });
        rrule_builder.toggle_custom_ordinal_fields();
      } else if (match) {
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
