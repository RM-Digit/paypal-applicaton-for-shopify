function tabify(selector_id,tabs_fitted){
    var tabs_id_array = [];
    if(tabs_fitted == 1){
        $('#'+selector_id+' ul').addClass('Polaris-Tabs--fitted');
    }
    $('#'+selector_id+' ul li').each(function(index, el) {
        var tab_id = $(this).find('button').attr('id')
        tabs_id_array.push('#'+ tab_id);
        $('.'+tab_id).css("display", "none");
    }); 
    $(tabs_id_array[0].replace('#', ".")).css({"display":"block","padding":"2rem 0px"});
    tabs_id_array = tabs_id_array.join();
    $("body").on('click', tabs_id_array, function(e) {
        $('#'+selector_id).find('li button').attr('aria-selected',false);
        $('#'+selector_id).find('li button').removeClass('Polaris-Tabs__Tab--selected');
        $(this).addClass('Polaris-Tabs__Tab--selected');
        $(this).attr('aria-selected',true);
        $('#'+selector_id).find('.tabify_tab').css("display", "none");
        $('.'+$(this).attr('id')).css({"display":"block","padding":"1.6rem 0px"});
    });
}

jQuery(document).ready(function($) {
    // apply tabify on home page
    tabify('Tabify',0);

    $('body').on('click','.copy',function(e){
        e.preventDefault();
        var aux = document.createElement("input");
        aux.setAttribute("value", document.getElementById('copyText').innerHTML);
        document.body.appendChild(aux);
        aux.select();
        document.execCommand("copy");
        document.body.removeChild(aux);
    });
});