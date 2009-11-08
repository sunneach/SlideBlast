function resizeLayout() {
    for (var i=0; i<document.jquerylayouts.length; i++) {
        document.jquerylayouts[i].resizeAll();
    }
   resizeCurrentSlide();
}

document.jquerylayouts=new Array();
setInterval("resizeLayout()", 200);

function enableSlideControls() {
    document.disable_slide_controls = false;
}

function disableSlideControls() {
    document.disable_slide_controls = true;
}

function toggleFullScreen() {
    if (!document.isFullScreen) {
        document.jquerylayouts[0].close("north");
        document.jquerylayouts[0].close("east");
        document.jquerylayouts[0].close("west");
				jQuery(".main.center").addClass("fullscreen");
        document.isFullScreen = true;
    } else {
        document.jquerylayouts[0].open("north");
        document.jquerylayouts[0].open("east");
        document.jquerylayouts[0].open("west");
				jQuery(".main.center").removeClass("fullscreen");
        document.isFullScreen = false;
    }
}

function setShareURL(obj) {
    var url = document.location.href;
    var pos = url.lastIndexOf("/");
    obj.value = url.substring(0, pos);
    obj.focus();
    obj.select();
}

function resizeCurrentSlide() {
		if (document.isFullScreen) {
			var offset=20;
		} else {
			var offset=80;
		}
    jQuery(".current_slide").filter(":visible").children("img").each(function(img) {
        if (!this.originalWidth) this.originalWidth = this.width;
        if (!this.originalHeight) this.originalHeight = this.height;
        var parentWidth= jQuery(this.parentNode.parentNode.parentNode).outerWidth() - offset;
        var parentHeight = jQuery(this.parentNode.parentNode.parentNode).outerHeight() - offset;
        resizeFunction(this, parentWidth, parentHeight, this.originalWidth, this.originalHeight);
    });
}

var resizeFunction = resizeFill;

function resizeFill(img, parentWidth, parentHeight, originalWidth, originalHeight) {
    var widthScaleFactor = originalWidth / parentWidth;
    var heightScaleFactor = originalHeight / parentHeight;

    if (widthScaleFactor > heightScaleFactor && widthScaleFactor > 1) {
        jQuery(img).width(parentWidth);
        jQuery(img).height(originalHeight / widthScaleFactor);
        return;
    } 
    
    if (heightScaleFactor > widthScaleFactor && heightScaleFactor > 1) {
        jQuery(img).height(parentHeight);
        jQuery(img).width(originalWidth / heightScaleFactor);
        return;
    }
    
    jQuery(img).width(originalWidth);
    jQuery(img).height(originalHeight);
}

function resizeToWidth(img, parentWidth, parentHeight, originalWidth, originalHeight) {
    resizeFill(img, parentWidth, 99999, originalWidth, originalHeight);
}