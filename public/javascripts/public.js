document.addEventListener('DOMContentLoaded', function(){

  GLightbox({
    selector: '.glightbox',
    afterSlideLoad: function(slideData) {
      var trigger = document.querySelectorAll('.glightbox')[slideData.index];
      var selector = trigger && trigger.dataset.creditSelector;
      if (!selector) return;

      var source = document.querySelector(selector);
      var container = slideData.slide.querySelector('.gdesc-inner');
      if (!source || !container) return;

      var target = container.querySelector('.gslide-desc');
      if (!target) {
        target = document.createElement('div');
        target.className = 'gslide-desc';
        container.appendChild(target);
      }
      target.innerHTML = source.innerHTML;
    }
  });

  document.getElementById("light-mode").addEventListener("change", () => {
    if (document.getElementById("light-mode").checked)
      localStorage.setItem("override-prefers-color-scheme", 1);
    else
      localStorage.removeItem("override-prefers-color-scheme");
  });
});
