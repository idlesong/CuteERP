// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require best_in_place
//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/2/jquery.dataTables.bootstrap
//= require_tree .

$(document).ready(function() {
  /* Activating Best In Place */
  jQuery(".best_in_place").best_in_place();

  $('.datatable').dataTable({
    "sDom": "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>",
    "sPaginationType": "bootstrap",
    "order": [ 1, 'asc' ]
  });

  $(".ajax-new").click(function(){
    //alert('Hello ajax!');
    new_url = $(this).attr('id');
    attr_data = $(this).attr('data');
    attr_data2 = $(this).attr('data-2');

    switch(new_url)
    {
      case "/items":
        obj_data = { item: { name: "new" ,imageURL: "rails.png" ,partNo: "unknown", price: 0.01 }};
        break;
      case "/contacts":
        obj_data = { contact: { name: "new", customer_id: attr_data}};
        break;
      case "/customers":
        obj_data = { customer: { name: "new" }};
        break;
      case "/opportunities":
        obj_data = { opportunity: { note: "new", project_type: "数字对讲机", customer_id: attr_data }};
        break;
      case "/oppostatuses":
        obj_data = { oppostatus: { status: "new", opportunity_id: attr_data, user_id: attr_data2 }};
        break;
      default:
          break;
    }

    $.ajax({
      type: "POST",
      url: new_url,
      data: obj_data,
      dataType:"JSON",
      success: function(data){
        //$("#image_center").html("<%= escape_javascript(render(:partial => 'items')) %>");
        //alert (data.id);
        //jQuery("#image_center").html(data.id);
        location.reload(true);
      },
      error: function(){
        alert('Error occured');
      }
    });
  });
});
