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
    plugins: 'code',
    toolbar: 'bold italic underline | bullist numlist | link unlink | blocks | code',
    extended_valid_elements: 'aggregate[tags|limit|order_by|order_direction|partial|conditions]',
    relative_urls: false,
    entity_encoding: 'raw',
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
    $("#metadata").hide();

    $("#button").click(function () {
      
      $("#metadata").slideToggle(1200);
      image_interface.initialize();

      if ($("#button").attr("class") == "unselected") {
        $("#button").attr("class", "selected");        
        
      }
      else {
        $("#button").attr("class", "unselected");
        $("#image_browser").hide();
        $("#image_browser_toggle").attr("class", "unselected");
      }
      
      return false;
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
  
        $("#flash").append("<img src='/images/ajax-loader.gif' alt='' />");
        $.post(this.attr("action"), $(this).serialize(), null, "script");
        
      }
    };
  
    setInterval('$("#page_editor > form").submitWithAjax()', 7000);
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
      

