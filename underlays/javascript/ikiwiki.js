// ikiwiki's javascript utility function library

var hooks = new Array;
window.onload = run_hooks_onload;

function run_hooks_onload() {
	run_hooks("onload");
}

function run_hooks(name) {
	for (var i = 0; i < hooks.length; i++) {
		if (hooks[i].name == name) {
			hooks[i].call();
		}
	}
}

function hook(name, call) {
	var h={name: name, call: call};
	hooks.push(h);
}

function getElementsByClass(cls, node, tag) {
        if (document.getElementsByClass)
                return document.getElementsByClass(cls, node, tag);
        if (! node) node = document;
        if (! tag) tag = '*';
        var ret = new Array();
        var pattern = new RegExp("(^|\\s)"+cls+"(\\s|$)");
        var els = node.getElementsByTagName(tag);
        for (i = 0; i < els.length; i++) {
                if ( pattern.test(els[i].className) ) {
                        ret.push(els[i]);
                }
        }
        return ret;
}
