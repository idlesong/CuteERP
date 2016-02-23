# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/
jQuery ->
  $("#exchange_rate").blur ->
    input_value = $('#exchange_rate').val();
    # alert input_value;
    # $('#cart').append("<%= escape_javascript(render(@cart, :input_exchange_rate => 10)) %>");
