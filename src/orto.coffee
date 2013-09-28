if $("body").width() < 1200 and $("body").height() < 1000
    startzoom = 15
else
    startzoom = 16
bounds = new L.LatLngBounds [60.114,24.750], [60.32, 25.300]
map = L.map 'map',
    minZoom: 11
    maxBounds: bounds
    zoomControl: false
map.addControl(new L.Control.Zoom({"position":"topright"}))
map.setView([60.171944, 24.941389], startzoom)
map.doubleClickZoom.disable()

osm_roads_layer = L.tileLayer('http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/60640/256/{z}/{x}/{y}.png',
    maxZoom: 18,
    #attribution: 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://cloudmade.com">CloudMade</a>'
)

get_wfs = (type, args, callback) ->
    url = GEOSERVER_BASE_URL + 'wfs/'
    params =
        service: 'WFS'
        version: '1.1.0'
        request: 'GetFeature'
        typeName: type
        srsName: 'EPSG:4326'
        outputFormat: 'application/json'
    for key of args
        params[key] = args[key]
    $.getJSON url, params, callback

marker = null
input_addr_map = null

$("#address-input").typeahead(
    source: (query, process_cb) ->
        url_query = encodeURIComponent(query)
        $.getJSON(GEOCODER_URL + 'v1/address/?format=json&name=' + url_query, (data) ->
            objs = data.objects
            ret = []
            input_addr_map = []
            for obj in objs
                if obj.name.indexOf(", Espoo") > -1
                    continue
                if obj.name.indexOf(", Vantaa") > -1
                    continue   
                ret.push(obj.name)
            input_addr_map = objs
            process_cb(ret)
        )
)
###        
nearby_markers = []

find_nearby_addresses = (target_coords) ->
    url = GEOCODER_URL + "v1/address/?format=json&lat=#{target_coords[0]}&lon=#{target_coords[1]}"
    $.getJSON(url, (data) ->
        objs = data.objects
        el = $("#nearby-addr-list")
        el.empty()
        for m in nearby_markers
            map.removeLayer m
        nearby_markers = []
        index = 1
        for addr in objs
            name = addr.name
            distance = Math.round(addr.distance)
            coords = addr.location.coordinates
            m = new L.Marker [coords[1], coords[0]],
                icon: new L.NumberedDivIcon {number: index.toString()}
            m.addTo map
            nearby_markers.push m
            el.append($("<li>#{addr.name} #{distance} m</li>"))
            index++
    )
###
$("#address-input").on 'change', ->
    match_obj = null
    for obj in input_addr_map
        if obj.name == $(this).val()
            match_obj = obj
            break
    if not match_obj
        return
    coords = obj.location.coordinates
    if not marker
        marker = L.marker([coords[1], coords[0]],
            draggable: false
        )
        marker.addTo(map)
    else
        marker.setLatLng([coords[1], coords[0]])
    map.setView([coords[1], coords[0]], 16)

input_district_map = null
active_district = null

$("#district-input").typeahead(
    source: (query, process_cb) ->
        $.getJSON(GEOCODER_URL + 'v1/district/', {input: query}, (data) ->
            objs = data.objects
            ret = []
            input_addr_map = []
            for obj in objs
                ret.push(obj.name)
            input_district_map = objs
            process_cb(ret)
        )
)

$("#district-input").on 'change', ->
    match_obj = null
    if not $(this).val().length
        if active_district
            map.removeLayer active_district
            active_district = null
        return

    for obj in input_district_map
        if obj.name == $(this).val()
            match_obj = obj
            break
    if not match_obj
        return

    if active_district
        map.removeLayer active_district
    borders = L.geoJson match_obj.borders,
        style:
            weight: 2
            fillOpacity: 0.08
    borders.bindPopup match_obj.name
    borders.addTo map
    map.fitBounds borders.getBounds()
    active_district = borders

slider_max = 2012
slider_min = 1812

current_state = {}

redraw_buildings = ->
    if not building_layer
        return
    building_layer.setStyle building_styler

update_screen = (val, force_refresh) ->
    
    if current_state.year != val
        current_state.year = val
        redraw_buildings()
        $("#current_year").html val
        

slider = $("#slider").slider
    min: slider_min
    max: slider_max
    value: slider_max
    tooltip: 'hide'
    handle: 'triangle'

slider.on 'slide', (ev) ->
    update_screen ev.value


select_year = (val) ->
    slider.slider 'setValue', val
    update_screen val

###
initialize_years = ->
    years = [1812,1912,2012]
    $year_list = $("#year_list")
    y_width = $year_list.width() / years.length
    for y, idx in years
        $text_el = $("<div>#{y}</div>")
        $text_el.css
            "font-size": "24px"
            "width": y_width
            "float": "left"
            "opacity": 1
            "text-align": "center"
            "cursor": "pointer"
        $text_el.data "index", idx
        $text_el.click ->
            idx = $(@).data 'index'
            select_year idx
        $year_list.append $text_el

initialize_years()

$(document).keydown (ev) ->
    val = current_state.val
    idx = Math.floor val / N_STEPS
    if ev.keyCode == 37 # left arrow
        idx = idx - 1
        if idx < 0
            idx = 0
    else if ev.keyCode == 39 # right arrow
        idx = idx + 1
        if idx == layer_count
            idx = layer_count - 1
    else
        return

    # if the keypress is for the map element, do not process it here.
    target = $(ev.target)
    if target.closest("#map").length
        return
    select_year idx
###

update_screen slider_max

colors = ['#FFFFD9', '#EDF8B1', '#C7E9B4', '#7FCDBB', '#41B6C4', '#1D91C0', '#225EA8', '#253494', '#081D58' ]

building_styler = (feat) ->
    ret =
        weight: 1
        opacity: 1.0
        fillOpacity: 1.0
    year = parseInt feat.properties.valmvuosi
    if current_state.year and year > current_state.year
        ret.opacity = 0
        ret.fillOpacity = 0
    if not year or year == 9999
        color = '#eee'
    else
        start_year = slider_min
        end_year = slider_max
        #if year < start_year
        #    year = start_year
        year += (end_year-1 - current_state.year)
        n = Math.floor (year - start_year) * colors.length / (end_year - start_year)
        n = colors.length - n - 1
        color = colors[n]
        if not color
            color = colors[colors.length-1]
    ret.color = color
    return ret

building_layer = null

display_building_modal = (feat) ->
    $(".modal").remove()
    modal = $("""
    <div class="modal hide fade" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-header">
            <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
            <h3>#{feat.address}</h3>
        </div>
        <div class="modal-body">
            <table class="table table-striped"><tbody>
            </tbody></table>
        </div>
        <div class="modal-footer">
            <button class="btn" data-dismiss="modal" aria-hidden="true">Sulje</button>
        </div>
    </div>
    """)
    $("body").append modal
    $tbody = modal.find 'tbody'
    for prop, val of feat.properties
        if not val
            continue
        if typeof val != 'string' and typeof val != 'number'
            continue
        arr = window.rakennukset_meta[prop.toLowerCase()]
        prop_name = ""
        if arr
            prop_name = arr[1]
        if not prop_name
            prop_name = prop
        $el = $("<tr><td>#{prop_name}</td><td>#{val}</td></tr>")
        $tbody.append $el
    modal.modal('show')

refresh_buildings = ->
    if map.getZoom() < 15
        if building_layer
            map.removeLayer building_layer
            building_layer = null
        return
    str = map.getBounds().toBBoxString() + ',EPSG:4326'
    get_wfs 'hel:rakennukset',
        maxFeatures: 2000
        bbox: str
        propertyName: 'valmvuosi,osoite,wkb_geometry_s2'
        , (data) ->
            if building_layer
                map.removeLayer building_layer
            building_layer = L.geoJson data,
                style: building_styler
                onEachFeature: (feat, layer) ->
                    year = feat.properties.valmvuosi
                    address = feat.properties.osoite
                    if address
                        address = address.replace /(\d){5} [A-Z]+/, ""
                    ###
                    use = feat.properties.kayttotark_taso3
                    if use
                        use = use.replace /(\d)+ /, ""
                    ###
                    popup = $("<div></div>")
                    popup.append $("<b>#{address}</b><br/>Valm.vuosi #{year}<br/>")
                    button = $("<button class='btn btn-primary'>Näytä lisätietoja</button>")
                    button.css
                        "margin-top": "20px"
                    popup.append button
                    button.click ->
                        get_wfs 'hel:rakennukset',
                            featureID: feat.id
                        , (data) ->
                            obj = data.features[0]
                            obj.address = address
                            display_building_modal obj
                    layer.bindPopup popup[0]
            building_layer.addTo map

map.on 'moveend', refresh_buildings

$(".infobut").click ->
    $(".infodiv").slideToggle()


map.addLayer osm_roads_layer
refresh_buildings()

animating = false
int = null
$("#play-btn").click ->
    if animating
        clearInterval int
        $(this).html "&#9658;"
    else
        $(this).html "&#9632;"
        if current_state.year is slider_max
            select_year slider_min
        int = setInterval () ->
                newyear = current_state.year + 1
                if newyear <= slider_max
                    select_year newyear
                else
                    clearInterval int
                    select_year slider_max
                    $("#play-btn").html "&#9658;"
                    animating = false
            , 50
    animating =  not animating

