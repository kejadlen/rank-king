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
})();
