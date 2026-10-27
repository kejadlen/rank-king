// Axis tags: Enter turns what was typed into a tag, × removes one. See
// lib/rank_king/views/axis_tags.rb for the markup this expects.
(function () {
  "use strict";

  document.addEventListener("keydown", function (event) {
    var input = event.target;
    if (event.key !== "Enter" || !input.closest || !input.closest("[data-tags] [data-dashed]")) return;

    event.preventDefault();
    var name = input.value.trim();
    if (!name) return;

    var tag = document.createElement("span");
    tag.className = "tag";
    tag.append(name);

    var hidden = document.createElement("input");
    hidden.type = "hidden";
    hidden.name = "axes[]";
    hidden.value = name;

    var remove = document.createElement("button");
    remove.type = "button";
    remove.setAttribute("aria-label", "Remove " + name);
    remove.textContent = "×";

    tag.append(hidden, remove);
    input.closest("[data-dashed]").before(tag);
    input.value = "";
  });

  document.addEventListener("click", function (event) {
    var remove = event.target.closest("[data-tags] .tag button");
    if (remove) remove.closest(".tag").remove();
  });

  // A destructive form asks first: <form data-confirm="Delete this list?">.
  document.addEventListener("submit", function (event) {
    var message = event.target.dataset.confirm;
    if (message && !window.confirm(message)) event.preventDefault();
  });

  // A slow form shows it is working: <form data-busy="Syncing…"> relabels
  // the button that sent it and marks it busy until the next page loads.
  document.addEventListener("submit", function (event) {
    var label = event.target.dataset.busy;
    var button = event.submitter;
    if (!label || !button || event.defaultPrevented) return;

    button.textContent = label;
    button.setAttribute("aria-busy", "true");
    setTimeout(function () { button.disabled = true; });
  });

  // The new-list form shows only the chosen source's fields. Disabling
  // the others keeps their required fields from blocking the submit.
  function showSource(select) {
    select.form.querySelectorAll("fieldset[data-source]").forEach(function (fieldset) {
      var chosen = fieldset.dataset.source === select.value;
      fieldset.disabled = !chosen;
      fieldset.hidden = !chosen;
    });
  }

  document.addEventListener("change", function (event) {
    if (event.target.matches("select[name=source]")) showSource(event.target);
  });

  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll("select[name=source]").forEach(showSource);
  });
})();
