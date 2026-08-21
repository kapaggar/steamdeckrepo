(function () {
  const el = document.getElementById("status");
  if (!el) return;

  fetch("http://127.0.0.1:3000/", { method: "GET", cache: "no-store" })
    .then(function (res) {
      if (res.ok) {
        el.textContent = "Open WebUI is running · tap the button";
        return;
      }
      el.textContent = "Open WebUI HTTP " + res.status + " · try: deck webui start";
    })
    .catch(function () {
      el.textContent = "Open WebUI not reachable · start it: deck webui start";
    });
})();
