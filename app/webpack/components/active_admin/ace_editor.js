import 'ace-builds';
import 'ace-builds/src-noconflict/mode-liquid'
import 'ace-builds/src-noconflict/mode-yaml'
import 'ace-builds/src-noconflict/theme-dreamweaver'
import { debounce } from 'throttle-debounce';

const updatePreview = () => {
  var form = $('#edit_mail_template');
  var url = form.attr('action') + '/preview.js';
  $.ajax({
    type: 'GET',
    url: form.attr('action') + '/preview',
    data: form.serialize()
  });
};

$(document).on('turbolinks:load', function() {
  $('#mail_preview').show();
  $('textarea.ace-editor').each(function() {
    var textarea = $(this);
    var editDiv = $('<div>').insertBefore(textarea);
    textarea.css('display', 'none');
    var editor = ace.edit(editDiv[0], {
      mode: 'ace/mode/' + this.dataset.mode,
      theme: 'ace/theme/dreamweaver',
      highlightActiveLine: false,
      showGutter: false,
      printMargin: false,
      useSoftTabs: true,
      tabSize: 2,
      wrapBehavioursEnabled: true,
      wrap: true,
      minLines: 10,
      maxLines: 30,
      fontSize: 14
    });

    editor.renderer.setPadding(12);
    editor.getSession().setValue(textarea.val());
    editor.getSession().on('change', debounce(1000, function() {
      textarea.val(editor.getSession().getValue());
      updatePreview();
    }));
  });
  $('input.mail_template_subject').on('input', debounce(1000, function() {
    updatePreview();
  }));
});
