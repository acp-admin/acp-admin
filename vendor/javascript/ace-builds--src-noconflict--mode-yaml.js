var e="undefined"!==typeof globalThis?globalThis:"undefined"!==typeof self?self:global;var t={};var n={exports:t};ace.define("ace/mode/yaml_highlight_rules",["require","exports","module","ace/lib/oop","ace/mode/text_highlight_rules"],(function(t,n,r){var o=t("../lib/oop");var i=t("./text_highlight_rules").TextHighlightRules;var YamlHighlightRules=function(){(this||e).$rules={start:[{token:"comment",regex:"#.*$"},{token:"list.markup",regex:/^(?:-{3}|\.{3})\s*(?=#|$)/},{token:"list.markup",regex:/^\s*[\-?](?:$|\s)/},{token:"constant",regex:"!![\\w//]+"},{token:"constant.language",regex:"[&\\*][a-zA-Z0-9-_]+"},{token:["meta.tag","keyword"],regex:/^(\s*\w[^\s:]*?)(:(?=\s|$))/},{token:["meta.tag","keyword"],regex:/(\w[^\s:]*?)(\s*:(?=\s|$))/},{token:"keyword.operator",regex:"<<\\w*:\\w*"},{token:"keyword.operator",regex:"-\\s*(?=[{])"},{token:"string",regex:'["](?:(?:\\\\.)|(?:[^"\\\\]))*?["]'},{token:"string",regex:/[|>][-+\d]*(?:$|\s+(?:$|#))/,onMatch:function(t,n,r,o){o=o.replace(/ #.*/,"");var i=/^ *((:\s*)?-(\s*[^|>])?)?/.exec(o)[0].replace(/\S\s*$/,"").length;var a=parseInt(/\d+[\s+-]*$/.exec(o));if(a){i+=a-1;(this||e).next="mlString"}else(this||e).next="mlStringPre";if(r.length){r[0]=(this||e).next;r[1]=i}else{r.push((this||e).next);r.push(i)}return(this||e).token},next:"mlString"},{token:"string",regex:"['](?:(?:\\\\.)|(?:[^'\\\\]))*?[']"},{token:"constant.numeric",regex:/(\b|[+\-\.])[\d_]+(?:(?:\.[\d_]*)?(?:[eE][+\-]?[\d_]+)?)(?=[^\d-\w]|$)$/},{token:"constant.numeric",regex:/[+\-]?\.inf\b|NaN\b|0x[\dA-Fa-f_]+|0b[10_]+/},{token:"constant.language.boolean",regex:"\\b(?:true|false|TRUE|FALSE|True|False|yes|no)\\b"},{token:"paren.lparen",regex:"[[({]"},{token:"paren.rparen",regex:"[\\])}]"},{token:"text",regex:/[^\s,:\[\]\{\}]+/}],mlStringPre:[{token:"indent",regex:/^ *$/},{token:"indent",regex:/^ */,onMatch:function(t,n,r){var o=r[1];if(o>=t.length){(this||e).next="start";r.shift();r.shift()}else{r[1]=t.length-1;(this||e).next=r[0]="mlString"}return(this||e).token},next:"mlString"},{defaultToken:"string"}],mlString:[{token:"indent",regex:/^ *$/},{token:"indent",regex:/^ */,onMatch:function(t,n,r){var o=r[1];if(o>=t.length){(this||e).next="start";r.splice(0)}else(this||e).next="mlString";return(this||e).token},next:"mlString"},{token:"string",regex:".+"}]};this.normalizeRules()};o.inherits(YamlHighlightRules,i);n.YamlHighlightRules=YamlHighlightRules}));ace.define("ace/mode/matching_brace_outdent",["require","exports","module","ace/range"],(function(t,n,r){var o=t("../range").Range;var MatchingBraceOutdent=function(){};(function(){(this||e).checkOutdent=function(e,t){return!!/^\s+$/.test(e)&&/^\s*\}/.test(t)};(this||e).autoOutdent=function(e,t){var n=e.getLine(t);var r=n.match(/^(\s*\})/);if(!r)return 0;var i=r[1].length;var a=e.findMatchingBracket({row:t,column:i});if(!a||a.row==t)return 0;var s=this.$getIndent(e.getLine(a.row));e.replace(new o(t,0,t,i-1),s)};(this||e).$getIndent=function(e){return e.match(/^\s*/)[0]}}).call(MatchingBraceOutdent.prototype);n.MatchingBraceOutdent=MatchingBraceOutdent}));ace.define("ace/mode/folding/coffee",["require","exports","module","ace/lib/oop","ace/mode/folding/fold_mode","ace/range"],(function(t,n,r){var o=t("../../lib/oop");var i=t("./fold_mode").FoldMode;var a=t("../../range").Range;var s=n.FoldMode=function(){};o.inherits(s,i);(function(){(this||e).getFoldWidgetRange=function(e,t,n){var r=this.indentationBlock(e,n);if(r)return r;var o=/\S/;var i=e.getLine(n);var s=i.search(o);if(-1!=s&&"#"==i[s]){var l=i.length;var g=e.getLength();var c=n;var h=n;while(++n<g){i=e.getLine(n);var u=i.search(o);if(-1!=u){if("#"!=i[u])break;h=n}}if(h>c){var d=e.getLine(h).length;return new a(c,l,h,d)}}};(this||e).getFoldWidget=function(e,t,n){var r=e.getLine(n);var o=r.search(/\S/);var i=e.getLine(n+1);var a=e.getLine(n-1);var s=a.search(/\S/);var l=i.search(/\S/);if(-1==o){e.foldWidgets[n-1]=-1!=s&&s<l?"start":"";return""}if(-1==s){if(o==l&&"#"==r[o]&&"#"==i[o]){e.foldWidgets[n-1]="";e.foldWidgets[n+1]="";return"start"}}else if(s==o&&"#"==r[o]&&"#"==a[o]&&-1==e.getLine(n-2).search(/\S/)){e.foldWidgets[n-1]="start";e.foldWidgets[n+1]="";return""}e.foldWidgets[n-1]=-1!=s&&s<o?"start":"";return o<l?"start":""}}).call(s.prototype)}));ace.define("ace/mode/yaml",["require","exports","module","ace/lib/oop","ace/mode/text","ace/mode/yaml_highlight_rules","ace/mode/matching_brace_outdent","ace/mode/folding/coffee","ace/worker/worker_client"],(function(t,n,r){var o=t("../lib/oop");var i=t("./text").Mode;var a=t("./yaml_highlight_rules").YamlHighlightRules;var s=t("./matching_brace_outdent").MatchingBraceOutdent;var l=t("./folding/coffee").FoldMode;var g=t("../worker/worker_client").WorkerClient;var Mode=function(){(this||e).HighlightRules=a;(this||e).$outdent=new s;(this||e).foldingRules=new l;(this||e).$behaviour=(this||e).$defaultBehaviour};o.inherits(Mode,i);(function(){(this||e).lineCommentStart=["#"];(this||e).getNextLineIndent=function(e,t,n){var r=this.$getIndent(t);if("start"==e){var o=t.match(/^.*[\{\(\[]\s*$/);o&&(r+=n)}return r};(this||e).checkOutdent=function(t,n,r){return(this||e).$outdent.checkOutdent(n,r)};(this||e).autoOutdent=function(t,n,r){(this||e).$outdent.autoOutdent(n,r)};(this||e).createWorker=function(e){var t=new g(["ace"],"ace/mode/yaml_worker","YamlWorker");t.attachToDocument(e.getDocument());t.on("annotate",(function(t){e.setAnnotations(t.data)}));t.on("terminate",(function(){e.clearAnnotations()}));return t};(this||e).$id="ace/mode/yaml"}).call(Mode.prototype);n.Mode=Mode}));(function(){ace.require(["ace/mode/yaml"],(function(e){n&&(n.exports=e)}))})();var r=n.exports;const o=n.exports.YamlHighlightRules,i=n.exports.MatchingBraceOutdent,a=n.exports.FoldMode,s=n.exports.Mode;export{a as FoldMode,i as MatchingBraceOutdent,s as Mode,o as YamlHighlightRules,r as default};

