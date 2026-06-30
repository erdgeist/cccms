$(document).ready(function(){

  GLightbox({ selector: '.glightbox' });

  document.getElementById("light-mode").addEventListener("change", () => {
    if (document.getElementById("light-mode").checked)
      localStorage.setItem("override-prefers-color-scheme", 1);
    else
      localStorage.removeItem("override-prefers-color-scheme");
  });
});
