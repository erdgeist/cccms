# db/seeds/chapters.rb
# Creates erfa and chaostreff chapter nodes under their respective parent nodes.
# Run with: bundle exec rails runner db/seeds/chapters.rb
#
# Parent nodes:
#   548 = erfas overview node
#   549 = chaostreffs overview node
#
# Each entry requires at minimum: slug, title_de, description_de, external_url
# Optional: title_en, description_en, location, events, review
# events: array of { rrule:, start_time:, tag_list:, location:, duration_hours: }
# Entries with review: true have known discrepancies between DE and EN content.

require 'date'

def seed_chapter(parent_id:, slug:, tag:, title_de:, description_de:,
                  external_url:, title_en: nil, description_en: nil,
                  location: nil, events: [], review: false)

  if review
    puts "  [REVIEW] #{slug} — check DE/EN discrepancy before publishing"
  end

  parent = Node.find(parent_id)

  # Skip if already exists
  if Node.find_by(slug: slug, parent_id: parent_id)
    puts "  Skipping #{slug} (already exists)"
    return
  end

  # Create node
  node = parent.children.create!(slug: slug, external_url: external_url)
  node.reload

  # Set up draft with German translation
  draft = node.draft
  draft.template_name = 'chapter_detail'
  I18n.with_locale(:de) do
    draft.title       = title_de
    draft.abstract    = location || ""
    draft.body        = description_de
    draft.tag_list    = tag
    draft.save!
  end

  # Add English translation if provided
  if title_en || description_en
    I18n.with_locale(:en) do
      draft.title    = title_en    || title_de
      draft.abstract = location    || ""
      draft.body     = description_en || description_de
      draft.save!
    end
  end

  # Set a system user as author (use first admin user)
  draft.user   = User.where(admin: true).first
  draft.editor = User.where(admin: true).first
  draft.save!

  # Publish
  node.publish_draft!
  node.reload

  # Create events
  events.each do |ev|
    base_time = Time.parse("#{Date.today.year}-01-01 #{ev[:start_time] || '19:00'}:00")
    node.events.create!(
      title:      title_de,
      location:   ev[:location] || location,
      rrule:      ev[:rrule],
      start_time: base_time,
      end_time:   base_time + (ev[:duration_hours] || 2).hours,
      tag_list:   ev[:tag_list] || 'open-day'
    )
  end

  puts "  Created: #{slug}#{review ? ' [needs review]' : ''}"
end

puts "Seeding erfas..."

erfas = [
  {
    slug: "erfa-aachen",
    title_de: "CCC Aachen",
    title_en: "CCC Aachen",
    description_de: "Der CCC Aachen ist regelmäßig zu Themen- und offenen Abenden für Besucher*innen geöffnet. Unsere kleinen aber feinen Clubräume voller Plüschhaie liegen zwischen Hauptbahnhof und Stadtzentrum und sind aus beiden Richtungen in wenigen Minuten Fußweg zu erreichen (Schützenstraße 11, 52062 Aachen). Dank bunter LEDs sind sie besonders abends nicht zu übersehen.",
    description_en: "CCC Aachen opens its doors regularly to themed and open evenings. Our small but cozy space full of plush sharks is located within a few minutes by foot from central station and the city center (Schützenstraße 11, 52062 Aachen). Thanks to colorful LEDs it's especially easy to find at night.",
    external_url: "https://ccc.ac/",
    location: "Schützenstraße 11, 52062 Aachen",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-bamberg",
    title_de: "backspace e.V. Bamberg",
    title_en: "backspace e.V. Bamberg",
    description_de: "Der Bamberger Erfa-Kreis und Hackerspace ist der backspace e.V., ein Zusammenschluss von Menschen, die technische Grenzen überwinden wollen, Innovationen erproben und den freien Wissensaustausch befördern. Der backspace ist Thinktank, Werkstatt, Hackerspace, Freiraum, Zuhause, Labor und Impulsgeber. Es ist fast immer was los, besonders am Dienstag ab 19 Uhr im Spiegelgraben 41, 96052 Bamberg.",
    description_en: "The CCC affiliated hackerspace backspace gathers people interested in technical innovation and free information exchange. It is a think tank, workshop, hackerspace, open space, home, laboratory and instigator. There is something going on every day, but most people meet at Spiegelgraben 41 in Bamberg on Tuesday, 7pm.",
    external_url: "https://www.hackerspace-bamberg.de/",
    location: "Spiegelgraben 41, 96052 Bamberg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-basel",
    title_de: "CCC Basel",
    title_en: "CCC Basel",
    description_de: "Die Türen des CCC Basel sind jeden Dienstagabend ab 19:30 Uhr geöffnet. Uns findet man an der Birsfelderstrasse 6 in CH-4132 Muttenz (Außentreppe zum Kellereingang). Falls du mit der Tram 14 vorfährst, empfehlen wir dir die Haltestelle Käppeli.",
    description_en: "CCC Basel opens its doors every Tuesday evening from 19:30. We are located at Birsfelderstrasse 6, 4132 Muttenz, Switzerland; just go down the outdoors stairway to the basement. If you arrive by public transit, we recommend taking tramway 14 to the stop Käppeli.",
    external_url: "https://ccc-basel.ch/",
    location: "Birsfelderstrasse 6, CH-4132 Muttenz",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:30" }
    ],
    review: false
  },
  {
    slug: "erfa-berlin",
    title_de: "CCC Berlin – Club Discordia",
    title_en: "CCC Berlin – Club Discordia",
    description_de: "Der Club Discordia ist ein öffentliches Treffen in den Clubräumen des CCC Berlin (Marienstraße 11, 10117 Berlin-Mitte). Die Treffen finden jeden Dienstag und Donnerstag ab ca. 19 Uhr statt.",
    description_en: "Club Discordia is a public meeting located at the CCC Berlin (Marienstr. 11, 10117 Berlin-Mitte). Meetings are held every Tuesday and Thursday at around 7pm.",
    external_url: "http://berlin.ccc.de/",
    location: "Marienstraße 11, 10117 Berlin",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU,TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-bremen",
    title_de: "CCC Bremen",
    title_en: "CCC Bremen",
    description_de: "Ein öffentliches Treffen des CCC Bremen findet jeweils dienstags ab 20 Uhr in der Zweigstraße 1 statt.",
    description_en: "The public get together of CCC Bremen takes place every Tuesday at 8pm at Z1 (Zweigstraße 1, 28217 Bremen).",
    external_url: "https://www.ccchb.de/",
    location: "Zweigstraße 1, 28217 Bremen",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "erfa-chemnitz",
    title_de: "CCC Chemnitz (ChCh)",
    title_en: nil,
    description_de: "Der Chaos Computer Club Chemnitz (ChCh) betreibt seit 2011 einen eigenen Hackspace in der Augustusburger Straße 102. Wir stehen allen technikinteressierten und kreativen Menschen offen und freuen uns immer über neue Gäste. Wir fühlen uns der Informationsfreiheit und der Aufklärung über die Auswirkungen aktueller Technologien auf die Gesellschaft verpflichtet. Trotzdem kommt bei uns auch der Spaß am Gerät nicht zu kurz.",
    description_en: nil,
    external_url: "https://chaoschemnitz.de",
    location: "Augustusburger Straße 102, Chemnitz",
    events: [],
    review: false
  },
  {
    slug: "erfa-darmstadt",
    title_de: "CCC Darmstadt",
    title_en: "CCC Darmstadt",
    description_de: "Wir treffen uns jeden Dienstagabend ab 19 Uhr zum gemeinsamen Basteln, Diskutieren, Hacken, Nerden – eben einfach zum offenen Chaos – in unserem Hackspace in der Wilhelminenstraße 17, mitten in der Darmstädter Innenstadt. Aber auch an <a href=\"https://www.chaos-darmstadt.de/termine.html\">jedem anderen Abend</a> ist in der Regel etwas los. Neben der Nutzung unserer Elektronikwerkstatt hast du zum Beispiel die Möglichkeit, bei unserem <a href=\"https://www.chaos-darmstadt.de/wizardsofdos.html\">Capture-the-Flag-Team „Wizards of DoS“</a> reinzuschauen oder dich bei <a href=\"https://darmstadt.freifunk.net\">Freifunk Darmstadt</a> zu engagieren. Aktuelle Termine und Neuigkeiten sowie den Türstatus gibt's auf <a href=\"https://www.chaos-darmstadt.de/\">chaos-darmstadt.de</a>. Im IRC findest du uns unter <a href=\"https://webirc.hackint.org/#chaos-darmstadt\">#chaos-darmstadt auf hackint</a>. Mailingliste: public&lt;ät&gt;lists.darmstadt.ccc.de. Schau doch einfach mal vorbei!",
    description_en: "CCC Darmstadt meets Tuesdays from 7pm in their hackspace at Wilhelminenstraße 17.",
    external_url: "https://www.chaos-darmstadt.de/",
    location: "Wilhelminenstraße 17, Darmstadt",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-dortmund",
    title_de: "CCC Dortmund",
    title_en: nil,
    description_de: "Der Erfa Dortmund ist ein Treffen von Dortmundern oder Leuten, die in der Dortmunder Umgebung wohnen (Unna, Holzwickede, Schwerte etc.). Wem kreativer Umgang mit Technik nicht fremd ist, ist herzlich zum Treff im Langen August in der Braunschweiger Straße 22 in Dortmund eingeladen. Treffen finden dienstags und donnerstags ab 19 Uhr (+1h Chaos-Verspätung) statt.",
    description_en: nil,
    external_url: "http://www.chaostreff-dortmund.de",
    location: "Braunschweiger Straße 22, Dortmund",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU,TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-dresden",
    title_de: "CCC Dresden (c3d2)",
    title_en: "CCC Dresden (c3d2)",
    description_de: "Die Chaoten aus dem ganzsächsischen bzw. südbrandenburgischen Raum treffen sich jeden Dienstag in Dresden (Details bitte jeweils <a href=\"http://www.c3d2.de/muc.html\">per Jabber unter c3d2@muc.hq.c3d2.de</a> erfragen). Darüberhinaus finden auch häufig, aber unregelmäßig Themenabende statt.",
    description_en: "The geeks from Saxony and southern Brandenburg meet every Tuesday in Dresden (<a href=\"http://www.c3d2.de/muc.html\">for details please ask via jabber at c3d2@muc.hq.c3d2.de</a>). Furthermore there are occasional get-togethers for specific subjects.",
    external_url: "http://www.c3d2.de/",
    location: "Dresden",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-duesseldorf",
    title_de: "Chaosdorf Düsseldorf",
    title_en: "Chaosdorf Düsseldorf",
    description_de: "Der Düsseldorfer Erfa (auch als Chaosdorf bekannt) betreibt einen Hackspace in der Sonnenstr. 58, der nahezu durchgehend geöffnet ist. Der Kennenlernabend, „Freitagsfoo“, findet jeden Freitag ab 18 Uhr statt.",
    description_en: "CCC Düsseldorf (aka Chaosdorf) operates a hackspace in Sonnenstraße 58 that is open nearly 24/7. The best method for getting to know it is the \"Freitagsfoo\" event, taking place every Friday from 6pm.",
    external_url: "https://chaosdorf.de/",
    location: "Sonnenstraße 58, Düsseldorf",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=FR", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "erfa-erlangen",
    title_de: "Bits'n'Bugs e.V. Erlangen",
    title_en: "Bits'n'Bugs e.V. Erlangen",
    description_de: "Der Bits'n'Bugs e.V. trifft sich jeden Freitag ab 18 Uhr im <a href=\"https://zam.haus/\">ZAM</a>, Hauptstr. 65-67, und zu weiteren unregelmäßigen Zeiten je nach Aktivitäten. Wir beteiligen uns außerdem regelmäßig an Veranstaltungen und Projekten des ZAM.",
    description_en: "Bits'n'Bugs e.V. meets every Friday at 6pm at ZAM, Hauptstraße 65-67, Erlangen, and at various other times depending on activities.",
    external_url: "http://erlangen.ccc.de/",
    location: "Hauptstraße 65-67, Erlangen",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=FR", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "erfa-essen",
    title_de: "Chaospott Essen",
    title_en: "Chaospott Essen",
    description_de: "Der Chaospott ist die lokale Vertretung des CCC im Herzen des Ruhrgebiets. Wir treffen uns jeden Mittwoch ab 19 Uhr in der Sibyllastraße 9, 45136 Essen (Hofgebäude).",
    description_en: "Chaospott is the local subsidiary of the CCC at the heart of the Ruhr area. We meet every Wednesday at 7pm at Sibyllastraße 9, 45136 Essen (Hofgebäude).",
    external_url: "http://chaospott.de/",
    location: "Sibyllastraße 9, 45136 Essen",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-flensburg",
    title_de: "CCC Flensburg",
    title_en: nil,
    description_de: "Deutschlands nördlichster Erfa trifft sich jeden Dienstag ab 18 Uhr in der Apenrader Straße 49, 24939 Flensburg. Bei unserem <a href=\"https://c3fl.de/mitmachen/openSpace/\">OpenSpace</a> sind neue Gesichter immer willkommen! Folgt uns gerne auch auf <a href=\"https://chaos.social/@chaos_fl\">Mastodon</a>.",
    description_en: nil,
    external_url: "https://c3fl.de/",
    location: "Apenrader Straße 49, 24939 Flensburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "erfa-frankfurt",
    title_de: "CCC Frankfurt am Main",
    title_en: "CCC Frankfurt am Main",
    description_de: "Wir treffen uns jeden Dienstag und Donnerstag (auch an den meisten Feiertagen) ab 19 Uhr in unserem Hackerspace, dem HQ. Dazu sind alle Interessierten jederzeit herzlich eingeladen.",
    description_en: "We meet every Tuesday and Thursday (even on most holidays) at 7pm in our hackspace the HQ. All interested people are welcome.",
    external_url: "http://ccc-ffm.de/hackerspace/",
    location: "Frankfurt am Main",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU,TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-freiburg",
    title_de: "CCC Freiburg",
    title_en: "CCC Freiburg",
    description_de: "Der Chaos Computer Club Freiburg trifft sich montags und dienstags ab 19 Uhr sowie nach Lust und Laune in seinen Räumen in der Adlerstraße 12a, 79098 Freiburg. Plenum ist jede zweite Woche dienstags ab 20 Uhr.",
    description_en: "CCC Freiburg meets on Mondays and Tuesdays from 7pm at Adlerstraße 12a, 79098 Freiburg. Plenum is every other Tuesday from 8pm.",
    external_url: "http://cccfr.de",
    location: "Adlerstraße 12a, 79098 Freiburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO,TU", start_time: "19:00" },
      { rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU", start_time: "20:00",
        tag_list: "plenum" }
    ],
    review: false
  },
  {
    slug: "erfa-fulda",
    title_de: "Magrathea Laboratories e.V. Fulda",
    title_en: nil,
    description_de: "Der Magrathea Laboratories e.V. (mag.lab) ist die lokale Chaosmanifestation und Treffpunkt einiger Haecksen, Hacker und anderweitig Technikinteressierter in der Lindenstraße 14 in Fulda. Das Chaos steht allen immer freitags ab 19 Uhr offen.",
    description_en: nil,
    external_url: "https://maglab.space/",
    location: "Lindenstraße 14, Fulda",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=FR", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-goettingen",
    title_de: "CCC Göttingen",
    title_en: "CCC Göttingen",
    description_de: "Der Erfa-Kreis Göttingen wurde im November 2007 von Hackern gegründet, die sich dem Chaos Computer Club nahefühlen. Open Chaos findet jeden zweiten Dienstag ab 20 Uhr im Neotopia (Von-Bar-Straße 2-4, Keller des MLP-Hauses) statt. Interessierte sind herzlich willkommen.",
    description_en: "Erfa Göttingen was founded Nov 2007 by hackers close to the Chaos Computer Club. Open Chaos is every other Tuesday from 8pm at Neotopia (Von-Bar-Straße 2-4). All interested people are welcome.",
    external_url: "http://www.chaostreff-goettingen.de/",
    location: "Von-Bar-Straße 2-4, Göttingen",
    events: [
      { rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "erfa-hamburg",
    title_de: "CCC Hamburg",
    title_en: "CCC Hamburg",
    description_de: "Der Hamburger Erfa-Kreis trifft sich in der Viktoria-Kaserne (1. Stock, Ostflügel), Zeiseweg 9, 22765 Hamburg. Der zweite Freitag und der letzte Dienstag im Monat sind perfekt zum Kennenlernen und Fragen stellen, weitere Termine finden sich auf dem <a href=\"https://www.hamburg.ccc.de/calendar/\">Kalender des Erfa Hamburg</a>, der mit öffentlichen Veranstaltungen gefüllt ist.",
    description_en: "The Erfakreis Hamburg meets at Viktoria-Kaserne, room 119 (1st floor, east wing) Zeiseweg 9, 22765 Hamburg. Every second Friday and last Tuesday of the month are great opportunities to meet people and ask questions.",
    external_url: "http://hamburg.ccc.de/",
    location: "Zeiseweg 9, 22765 Hamburg",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=2FR", start_time: "19:00" },
      { rrule: "FREQ=MONTHLY;BYDAY=-1TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-hannover",
    title_de: "CCC Hannover",
    title_en: "CCC Hannover",
    description_de: "Das regionale Chaos in Hannover trifft sich jeden Mittwoch ab 19 Uhr in der Bürgerschule im Clubraum (Raum 3.1) im Stadtteilzentrum Nordstadt.",
    description_en: "The regional Chaos in Hannover meets every Wednesday from 7pm at the Bürgerschule in their clubroom (room 3.1) in the community center Nordstadt.",
    external_url: "https://hannover.ccc.de/",
    location: "Bürgerschule, Raum 3.1, Hannover",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-kaiserslautern",
    title_de: "Chaos inKL. e.V. Kaiserslautern",
    title_en: nil,
    description_de: "Der Chaos inKL. e.V. ist die Kaiserslauterner Niederlassung des Chaos Computer Clubs. Unsere öffentlichen Veranstaltungen sind die Hacknight (der samstägliche Basteltreff ab 19 Uhr), das monatliche Seminar und das monatliche Kneipentreffen.",
    description_en: nil,
    external_url: "http://www.chaos-inkl.de/",
    location: "Kaiserslautern",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=SA", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-karlsruhe",
    title_de: "Entropia e.V. Karlsruhe",
    title_en: "Entropia e.V. Karlsruhe",
    description_de: "Der <a href=\"https://entropia.de/\">Erfa-Kreis Karlsruhe</a> ist ein eingetragener Verein mit dem Namen Entropia. Die öffentlichen <a href=\"https://entropia.de/Treffen\">Treffen</a> finden jeden Samstag ab 19:30 Uhr in <a href=\"https://entropia.de/Clubr%C3%A4ume\">den Räumen des Erfa Karlsruhe</a> (Gewerbehof, Steinstraße 23) statt und richten sich an alle aus Karlsruhe und dem Umland.",
    description_en: "Erfa Karlsruhe is a registered club with the name 'Entropia'. The public meetings take place every Saturday from 7:30pm at our club (Gewerbehof, Steinstr. 23) and targets people from Karlsruhe and surrounding region.",
    external_url: "https://entropia.de/",
    location: "Steinstraße 23, Karlsruhe",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=SA", start_time: "19:30" }
    ],
    review: false
  },
  {
    slug: "erfa-kassel",
    title_de: "flipdot e.V. Kassel",
    title_en: "flipdot e.V. Kassel",
    description_de: "flipdot e.V. hackerspace kassel ist der lokale Erfa-Kreis – ein lebendiger Ort mit viel Platz zum Bausteln und Coden. Es gibt gut ausgestattete Werkstatträume, Vortrags- und Kinoraum und eine Küche mit Profi-Pizzaofen. Im flipdot wird sehr oft zusammen gekocht und gegessen. flipdot ist seit 2009 Brutstätte neuer Ideen, Wohnzimmer, anarchistische Volkshochschule, Coder-Cave und umtriebige Werkstatt. Offen für Besucher jeden Dienstag ab 19 Uhr, Schillerstraße 25, 34117 Kassel.",
    description_en: "flipdot e.V. hackerspace kassel is the local Erfa circle – a lively place with plenty of space for building and coding. There are well-equipped workshop rooms, a lecture and cinema room, and a kitchen with a professional pizza oven. At flipdot, people often cook and eat together. Since 2009, flipdot has been a breeding ground for new ideas, a living room, an anarchist adult education center, a coder's cave, and a bustling workshop. Open to visitors every Tuesday from 7pm, Schillerstraße 25, 34117 Kassel.",
    external_url: "http://kassel.ccc.de/",
    location: "Schillerstraße 25, 34117 Kassel",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-koeln",
    title_de: "c4 Köln",
    title_en: "c4 Cologne",
    description_de: "Der c4 ist der westliche Brückenkopf des innovativen Technologieeinsatzes mit allen Features, die zum Chaos gehören. Öffentliche Treffen gibt es jeden Donnerstag ab 19:30 Uhr im Chaoslabor in Köln-Ehrenfeld, an jedem letzten Donnerstag im Monat gibt es ein OpenChaos als Vortragsrahmenprogramm.",
    description_en: "The c4 is a westward bridge head of the innovative technology usage with all features that are necessary for chaos. The public meeting is called OpenChaos and takes place on the last Thursday of the month at 19:30 in the Chaoslabor in Cologne-Ehrenfeld.",
    external_url: "http://koeln.ccc.de/",
    location: "Köln-Ehrenfeld",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "19:30" }
    ],
    review: false
  },
  {
    slug: "erfa-leipzig",
    title_de: "dezentrale e.V. Leipzig",
    title_en: nil,
    description_de: "Der dezentrale e.V. vertritt als Erfa das lokale Chaos in Leipzig. Wir bieten einen Anlaufpunkt für Softwarenerds, Künstler:innen, Hardwareschraubende und -löter:innen und alle chaosnahen Themen. Infos über uns findest Du unter <a href=\"http://dezentrale.space\">dezentrale.space</a>. Unser Vernetzungsabend ist der Chaostreff jeden Freitag ab 19:00.",
    description_en: nil,
    external_url: "http://dezentrale.space",
    location: "Leipzig",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=FR", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-luebeck",
    title_de: "Chaotikum e.V. Lübeck",
    title_en: "Chaotikum e.V. Lübeck",
    description_de: "Der Lübecker Erfa ist der Chaotikum e.V., welcher seit 2012 den Hackspace Nobreakspace betreibt. Dort treffen sich seitdem technikinteressierte Menschen, um an diversen Projekten zu arbeiten, über Themen zu reden, die uns beschäftigen, und vor allem um Spaß zu haben. Open Space ist immer Mittwochs ab 19:00 Uhr.",
    description_en: "The Lübeck Hackspace group is Chaotikum e.V., which has been running the Nobreakspace hackspace since 2012. Since then, tech enthusiasts have been meeting there to work on various projects, discuss topics that interest them, and above all, have fun. Open Space is every Wednesday from 7:00 PM.",
    external_url: "https://chaotikum.org",
    location: "Lübeck",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-mainz-wiesbaden",
    title_de: "CCC Mainz/Wiesbaden",
    title_en: "CCC Mainz/Wiesbaden",
    description_de: "Das Wiesbadener Chaos trifft sich jeden Dienstag ab 19 Uhr in seinen Räumen am Sedanplatz 7 in Wiesbaden. Die Treffen richten sich an alle aus Mainz/Wiesbaden und dem nahen Umland.",
    description_en: "The Chaos Computer Club Mainz meets every Tuesday, 7pm, at Sedanplatz 7 in Wiesbaden. The meetup is addressed to everyone from Mainz/Wiesbaden and the near surroundings.",
    external_url: "http://www.cccmz.de",
    location: "Sedanplatz 7, Wiesbaden",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-mannheim",
    title_de: "CCC Mannheim",
    title_en: "CCC Mannheim",
    description_de: "Der Erfa-Kreis Mannheim ist eine Anlaufstelle für Computer- und Technikinteressierte, die Gleichgesinnte suchen. Hier kann man sich austauschen, seine Ideen präsentieren und diskutieren. Unsere öffentlichen Treffen finden jeden Freitag ab 19 Uhr statt. Die Termine stehen in unserem Wiki.",
    description_en: "Erfa Mannheim is a local contact point for people that are interested in computer and technology, who search for like minded people. You can exchange, present and discuss your ideas. Our public meeting takes place every Friday from 7pm.",
    external_url: "http://www.ccc-mannheim.de",
    location: "Mannheim",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=FR", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-muenchen",
    title_de: "µC³ München",
    title_en: "µC³ Munich",
    description_de: "Die öffentlichen Treffen des µC³ finden am zweiten Dienstag jeden Monats ab ca. 20 Uhr im Club in der Schleißheimer Straße 39 (Ecke Heßstraße 90) statt. Dies ist natürlich auch ein Ort, um jederzeit mit jemandem des Münchner CCCs ins Gespräch zu kommen.",
    description_en: "The public meetup of the µC³ takes places every second Tuesday of the month, starting at about 8pm at Schleißheimer Str. 39 (corner to Heßstraße 90).",
    external_url: "https://muc.ccc.de/",
    location: "Schleißheimer Straße 39, München",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=2TU", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "erfa-offenburg",
    title_de: "Section77 e.V. Offenburg",
    title_en: nil,
    description_de: "Der lockere Treff von Section77 e. V. für alle Chaos-Interessierten aus dem Raum Offenburg findet jeden Dienstag ab 20 Uhr im Hackspace statt. Dieser befindet sich in der Hauptstraße 1 in Offenburg (direkt im Bahnhofsgebäude). Gäste sind immer willkommen.",
    description_en: nil,
    external_url: "https://section77.de",
    location: "Hauptstraße 1, Offenburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "erfa-paderborn",
    title_de: "CCC Paderborn (subraum)",
    title_en: "CCC Paderborn",
    description_de: "Wir treffen uns immer mittwochs in unserem Hackerspace \"subraum\" in der Westernmauer 12-16.",
    description_en: "We meet every Wednesday at our hackspace \"subraum\" in Westernmauer 12-16, Paderborn.",
    external_url: "https://www.c3pb.de/",
    location: "Westernmauer 12-16, Paderborn",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-salzburg",
    title_de: "Erfa Salzburg",
    title_en: nil,
    description_de: "Der Erfa Salzburg ist eine als eingetragener Verein organisierte und trotzdem lockere Runde von Leuten, die sich mit dem Chaos Computer Club e.V. eng verbunden fühlen. Wir versuchen, einen Blick hinter die Kulissen zu werfen und viele Dinge zu hinterfragen und zu diskutieren.",
    description_en: nil,
    external_url: "http://sbg.chaostreff.at/",
    location: "Salzburg",
    events: [],
    review: false
  },
  {
    slug: "erfa-siegen",
    title_de: "Chaos Siegen",
    title_en: nil,
    description_de: "Chaos Siegen besteht aus einer Handvoll freundlicher und offener Menschen mit einer Leidenschaft für Netzpolitik, dem Chaos Computer Club im Hintergrund und gestrandet im Hackspace Siegen durch die Wirren unserer Galaxie. #tuwat und komm vorbei!",
    description_en: nil,
    external_url: "https://c3si.de/",
    location: "Siegen",
    events: [],
    review: false
  },
  {
    slug: "erfa-stralsund",
    title_de: "Port39 e.V. Stralsund",
    title_en: "Port39 e.V. Stralsund",
    description_de: "Als erster Erfa in Mecklenburg-Vorpommern sorgen wir als Port39 e.V. in Stralsund und Umgebung für eine ordentliche Portion Chaos. Mit Chaos macht Schule, Vorträgen und Workshops, Hacking-Sessions, Löt-Workshops, RepairCafés und vielem mehr wollen wir Jung und Alt für Technik, IT und allem, was dazu gehört, begeistern, und mit diversen Projekten im eigenen Hackerspace mal mehr, mal weniger sinnvolle Dinge anstellen. Kommt gerne rum oder schaut auf unserer <a href=\"https://port39.de\">Website</a> oder auf <a href=\"https://chaos.social/@Port39\">Mastodon</a> vorbei. Definitiv da sind wir jeden Donnerstag zum Chaostreff ab 19 Uhr und jeden 2. &amp; 4. Samstag ab 14 Uhr zum OpenSpace.",
    description_en: "As the first Erfa in Mecklenburg-Western Pomerania, we at Port39 e.V. make sure that there's a healthy dose of chaos in Stralsund and the surrounding area. Through \"Chaos macht Schule\" events, lectures, workshops, hacking sessions, soldering workshops, Repair Cafés, and much more, we aim to inspire people of all ages to get excited about technology, IT, and everything that goes with it. Feel free to drop by or check out our <a href=\"https://port39.de\">website</a> or <a href=\"https://chaos.social/@Port39\">Mastodon</a>. We're definitely there every Thursday for the Chaos Meetup starting at 7pm and every 2nd &amp; 4th Saturday starting at 2pm for OpenSpace.",
    external_url: "https://port39.de",
    location: "Stralsund",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "19:00" },
      { rrule: "FREQ=MONTHLY;BYDAY=2SA,4SA", start_time: "14:00",
        tag_list: "open-day open-space", duration_hours: 4 }
    ],
    review: false
  },
  {
    slug: "erfa-stuttgart",
    title_de: "CCC Stuttgart",
    title_en: "CCC Stuttgart",
    description_de: "Der Chaos Computer Club Stuttgart e.V. trifft sich jeden ersten Dienstag im Monat im Lichtblick in der Stadtmitte (Reinsburgstraße 13) ab 18:30 Uhr und jeden dritten Mittwoch im Monat im Shackspace (Ulmer Straße 255) ab 18:30 Uhr. Im Shackspace kann Bastelhardware gerne mitgebracht werden. Jeden zweiten Donnerstag im Monat haben wir unsere Vortragsreihe in der Stadtbibliothek Stuttgart am Mailänder Platz.",
    description_en: "CCC Stuttgart meets every first Tuesday of the month at Lichtblick (Reinsburgstraße 13) from 6:30pm and every third Wednesday of the month at Shackspace (Ulmer Straße 255) from 6:30pm. Our monthly talk series is every second Thursday of the month at the public library at Mailänder Platz.",
    external_url: "https://www.cccs.de/",
    location: "Stuttgart",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=1TU", start_time: "18:30",
        location: "Reinsburgstraße 13, Stuttgart" },
      { rrule: "FREQ=MONTHLY;BYDAY=3WE", start_time: "18:30",
        location: "Ulmer Straße 255, Stuttgart" }
    ],
    review: false
  },
  {
    slug: "erfa-ulm",
    title_de: "Chaostreff Ulm",
    title_en: "Chaostreff Ulm",
    description_de: "Der Chaostreff Ulm findet jeden Montag ab 19:30 Uhr im Café Einstein an der Uni Ulm statt, außer jeden zweiten Montag des Monats. Dieser ist dem Chaosseminar vorbehalten.",
    description_en: "The Chaostreff Ulm takes place every Monday at 7:30pm at Café Einstein, Uni Ulm, except every second Monday which is reserved for the Chaos seminar.",
    external_url: "http://www.ulm.ccc.de/",
    location: "Café Einstein, Uni Ulm",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "19:30" }
    ],
    review: false
  },
  {
    slug: "erfa-unna",
    title_de: "CCC Unna (UN-Hack-Bar)",
    title_en: "CCC Unna (UN-Hack-Bar)",
    description_de: "Der CCC Unna trifft sich für gewöhnlich jeden Donnerstag ab ca. 19 Uhr in den Räumen der UN-Hack-Bar. Dort quatschen wir über allerlei Dinge wie z. B. Netzpolitik, Politik im Allgemeinen, Computer &amp; Technik, aber auch schonmal darüber, wie man einen brennenden Feuerlöscher löscht oder das neueste Internet-Meme. ;-) Natürlich wird auch gebastelt, gebaut und im besten Sinne gehackt. Gäste aller Couleur sind gern gesehen.",
    description_en: "The CCC Unna usually meets every Thursday at around 7pm in the rooms of the UN-Hack-Bar. We chat about all kinds of topics: from net politics and politics in general to computers and technology, and sometimes even about odd questions like how to extinguish a burning fire extinguisher or the latest internet meme. ;-) Of course, we also tinker, build, and hack things in the best possible sense. Guests of all kinds are very welcome.",
    external_url: "https://www.un-hack-bar.de/ccc-unna/",
    location: "Unna",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-wien",
    title_de: "CCC Wien",
    title_en: "CCC Vienna",
    description_de: "Der Chaos Computer Club Wien trifft sich einmal im Monat, meistens im <a href=\"https://metalab.at/\">Metalab</a>. Details zu den Treffen werden <a href=\"https://c3w.at/events/\">auf der Webseite des C3W</a> bekanntgegeben. Für Fragen und allgemeine Announcements stehen die <a href=\"https://c3w.at/mitmachen/\">öffentliche C3W-Mailingliste</a> oder <a href=\"https://chaos.social/@C3Wien\">@C3Wien@chaos.social</a> bereit. Komm vorbei!",
    description_en: "The Chaos Computer Club Vienna meets once a month, usually at <a href=\"https://metalab.at/\">Metalab</a>. Find details on <a href=\"https://c3w.at/events/\">our website</a>. Use the <a href=\"https://c3w.at/mitmachen/\">public mailinglist</a> or <a href=\"https://chaos.social/@C3Wien\">@C3Wien@chaos.social</a> to ask questions or to receive announcements. Come by!",
    external_url: "https://c3w.at/",
    location: "Metalab, Wien",
    events: [
      { rrule: "FREQ=MONTHLY", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "erfa-wuerzburg",
    title_de: "Nerd2Nerd Würzburg",
    title_en: nil,
    description_de: "Nerd2Nerd trifft sich jeden Donnerstag ab 18 Uhr im FabLab Würzburg.",
    description_en: nil,
    external_url: "http://nerd2nerd.org/",
    location: "FabLab Würzburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "erfa-zuerich",
    title_de: "CCCZH Zürich",
    title_en: "CCCZH Zurich",
    description_de: "Der CCCZH ist Teil des Hackerspace <a href=\"https://www.bitwaescherei.ch/\">bitwäscherei</a>. Von Züri Hardbrücke aus einen halben Katzensprung in die Zentralwäscherei Zürich an der Neuen Hard 12.",
    description_en: "The CCCZH is part of the hackspace bitwäscherei, a short walk from Zürich Hardbrücke at Neue Hard 12.",
    external_url: "https://www.ccczh.ch/",
    location: "Neue Hard 12, Zürich",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  }
]

erfas.each do |entry|
  seed_chapter(parent_id: 548, tag: "erfa-detail", **entry)
end

puts "Seeding chaostreffs..."

chaostreffs = [
  {
    slug: "chaostreff-aalen",
    title_de: "Chaostreff Aalen",
    title_en: nil,
    description_de: "Wir sind ein Chaostreff und Hackspace in Aalen im Aaccellerator, Blezingerstraße 15, 73430 Aalen. Wir treffen uns regelmäßig jeden 3. Dienstag im Monat ab 18:30 Uhr. Für Treffen außerhalb von den Regelterminen verabreden wir uns spontan über <a href=\"https://matrix.to/#/#makerspace-aalen:famhahn.xyz\">Matrix</a>.",
    description_en: nil,
    external_url: "https://aalen.space/",
    location: "Blezingerstraße 15, 73430 Aalen",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=3TU", start_time: "18:30" }
    ],
    review: false
  },
  {
    slug: "chaostreff-alzey",
    title_de: "Chaostreff Alzey",
    title_en: nil,
    description_de: "An jedem ersten Sonntag des Monats trifft sich der Chaostreff Alzey um 15 Uhr im Juku Alzey. All creatures welcome!",
    description_en: nil,
    external_url: "https://chaostreff-alzey.de/",
    location: "Juku Alzey",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=1SU", start_time: "15:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-amberg-sulzbach",
    title_de: "Chaostreff Amberg-Sulzbach",
    title_en: nil,
    description_de: "Wir treffen uns monatlich in Amberg in lockerer Runde. Es wird keine Anmeldung benötigt. All Creatures Welcome! Ort und Zeit der Treffen findet ihr auf der Webseite des Chaostreffs.",
    description_en: nil,
    external_url: "https://amborg-sulzbyte.de/",
    location: "Amberg",
    events: [
      { rrule: "FREQ=MONTHLY" }
    ],
    review: false
  },
  {
    slug: "chaostreff-amsterdam",
    title_de: "Chaos Amsterdam",
    title_en: "Chaos Amsterdam",
    description_de: "Chaos Amsterdam meets on Thursdays every other week at 19:00 in a social space close to the city center. We can be found on <a href=\"https://webirc.hackint.org/#chaosamsterdam\">IRC in #chaosamsterdam</a> on the hackint network.",
    description_en: "Chaos Amsterdam meets on Thursdays every other week at 19:00 in a social space close to the city center. We can be found on <a href=\"https://webirc.hackint.org/#chaosamsterdam\">IRC in #chaosamsterdam</a> on the hackint network.",
    external_url: "https://chaos.amsterdam/",
    location: "Amsterdam",
    events: [
      { rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-andernach",
    title_de: "haxko e.V. Andernach",
    title_en: nil,
    description_de: "Der Hacker- und Makerspace Mayen-Koblenz (haxko e.V.) befindet sich in der ehemaligen Gastwirtschaft des Bahnhofs Andernach. Unsere Treffen finden in geraden Kalenderwochen freitags und in ungeraden samstags statt. Beginn immer ab 18 Uhr. Thematisch sind wir offen und durch die Location direkt am Bahnhof gut zu erreichen.",
    description_en: nil,
    external_url: "https://haxko.space",
    location: "Bahnhof Andernach",
    events: [
      { rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=FR", start_time: "18:00" },
      { rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=SA", start_time: "18:00" }
    ],
    review: true
  },
  {
    slug: "chaostreff-augsburg",
    title_de: "OpenLab Augsburg",
    title_en: nil,
    description_de: "Aus dem <a href=\"https://c3a.de\">Chaostreff Augsburg</a> entstanden ist das <a href=\"https://openlab-augsburg.de\">OpenLab</a> heute der Anlaufpunkt für alle die an nachhaltigem Handeln &amp; Herstellen, dem kreativem Umgang mit Technik, Datenschutz und digitaler Selbstbemächtigung interessiert sind. Jeden Donnerstag offen für Interessierte und jeden dritten Donnerstag auch mit Vortrag im bekannten Chaostreff-Stil.",
    description_en: nil,
    external_url: "https://openlab-augsburg.de",
    location: "Augsburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-aschaffenburg",
    title_de: "Makerspace Schaffenburg",
    title_en: nil,
    description_de: "Der Chaostreff im Makerspace Schaffenburg ist ein Zusammenschluss von technikbegeisterten Menschen, die zusammen in (A)schaffenburg einen Ort schaffen, der genau dies bietet: Platz und Werkzeug zum Arbeiten, motivierte Menschen mit Know-How, kreative Ideen und Inspiration. Kurz gesagt: Raum für alle, die etwas machen wollen – ein Makerspace! Zu finden sind wir in der Dorfstraße 1 in Aschaffenburg.",
    description_en: nil,
    external_url: "http://www.schaffenburg.org",
    location: "Dorfstraße 1, Aschaffenburg",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-backnang",
    title_de: "Chaostreff Backnang",
    title_en: nil,
    description_de: "Wir treffen uns an jedem 3. Sonntag des Monats zum Erfahrungsaustausch und der gemeinsamen Umsetzung von Projekten sowie an jedem 1. Dienstag im Monat zum offenen Stammtisch im dasWohnzimmer (Willy-Brandt-Platz 2) in Backnang bei Stuttgart und freuen uns auf neue Gesichter. Strom, Freifunk sowie Getränke und Snacks der Bar (auch Mate) werden angeboten.",
    description_en: nil,
    external_url: "https://chaostreff-backnang.de/",
    location: "Willy-Brandt-Platz 2, Backnang",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=3SU", start_time: "18:00" },
      { rrule: "FREQ=MONTHLY;BYDAY=1TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-bayreuth",
    title_de: "Imaginärraum Bayreuth",
    title_en: nil,
    description_de: "Der Imaginärraum ist ein junger Hackerspace, der sich jeden Montag um 19 Uhr in seinen Räumen in der Schulstraße 7 in Bayreuth trifft.",
    description_en: nil,
    external_url: "https://imaginaerraum.de/",
    location: "Schulstraße 7, Bayreuth",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-bern",
    title_de: "Chaostreff Bern",
    title_en: nil,
    description_de: "Der Chaostreff Bern trifft sich jeden Dienstag ab 19 Uhr im eigenen Hackerspace an der Zwyssigstrasse 45. Dort gibt es Strom, Internet, Mate und viel Platz zum Hacken.",
    description_en: nil,
    external_url: "https://www.chaostreffbern.ch/",
    location: "Zwyssigstrasse 45, Bern",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-bielefeld",
    title_de: "Hackerspace Bielefeld",
    title_en: nil,
    description_de: "Bielefeld gibt's gar nicht? Weiß man nicht. Gibt es denn einen Chaostreff? Auch das ist ungewiss, aber chaosnahe Leute treffen sich im <a href=\"http://hackerspace-bielefeld.de/\">Hackerspace Bielefeld</a>.",
    description_en: nil,
    external_url: "http://hackerspace-bielefeld.de/",
    location: "Bielefeld",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-bingen",
    title_de: "/bin/hacken Bingen",
    title_en: nil,
    description_de: "Seit Anfang 2019 sind wir /bin/hacken, ein Hacker- &amp; Makerspace in Bingen am Rhein. Wir bieten wöchentliche Treffen und eine offene Werkstatt zum Mitgestalten oder einfach eigene Projekte verwirklichen!",
    description_en: nil,
    external_url: "https://binhacken.de/",
    location: "Bingen am Rhein",
    events: [
      { rrule: "FREQ=WEEKLY", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-bochum",
    title_de: "Das Labor Bochum",
    title_en: nil,
    description_de: "Das Labor, Hackspace und Chaostreff, ist in erster Linie ein Ort, an dem praktisch gearbeitet wird. Wir benutzen und entwickeln freie Software, löten, ätzen und programmieren Mikrocontroller, beschäftigen uns mit 3D-Druck, Freifunk, Amateurfunk, IT-Sicherheit, Arduinos, OSM oder Open Science. Wir haben den Anspruch, mit Technologie Neues und Sinnvolles zu erschaffen. Im Labor gibt es Vorträge, Workshops und Diskussionen zu den unterschiedlichsten Bereichen der Technik.",
    description_en: nil,
    external_url: "https://das-labor.org",
    location: "Bochum",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-bonn",
    title_de: "Datenburg e.V. Bonn",
    title_en: nil,
    description_de: "Der Datenburg e.V. ist ein seit 2019 existierender Hackspace und Chaostreff in Bonn und seit Anfang 2024 ein eingetragener Verein. Wir beschäftigen uns mit Themen rund um Technik und Gesellschaft. Die Datenburg ist auch ein Ort, um an eigenen Projekten zu arbeiten und sich auszutauschen. Wir öffnen jeden Dienstag ab 20 Uhr unsere Tore für alle interessierten Wesen.",
    description_en: nil,
    external_url: "https://datenburg.org/",
    location: "Bonn",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-budapest",
    title_de: "H.A.C.K. Budapest",
    title_en: "H.A.C.K. Budapest",
    description_de: "Members of the Hungarian Autonomous Center for Knowledge (H.A.C.K.) usually meet on Tuesdays at 19:00 local time, but it's best to confirm beforehand on #hspbp at IRCnet. We're located in the middle of the city, and we have Mate, sticker exchange, Internet, and friendly hackers.",
    description_en: "Members of the Hungarian Autonomous Center for Knowledge (H.A.C.K.) usually meet on Tuesdays at 19:00 local time, but it's best to confirm beforehand on #hspbp at IRCnet. We're located in the middle of the city, and we have Mate, sticker exchange, Internet, and friendly hackers.",
    external_url: "https://hsbp.org/contact-us",
    location: "Budapest",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-coburg",
    title_de: "Hackzogtum Coburg",
    title_en: nil,
    description_de: "Coburgs Chaostreff/Hackspace ist das Hackzogtum Coburg. Bei uns stehen vor allem Spaß an der Technik und reger Austausch im Vordergrund. Wer vorbeischauen will, ist bei uns immer willkommen. Ihr findet uns physikalisch in der Heiligkreuzstr. 3 in 96450 Coburg. Die meisten Leute gleichzeitig treffen sich immer dienstags ab 20 Uhr.",
    description_en: nil,
    external_url: "https://hackzogtum-coburg.de",
    location: "Heiligkreuzstr. 3, 96450 Coburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-cottbus",
    title_de: "Chaostreff Cottbus",
    title_en: nil,
    description_de: "Der Treff für alle Chaos-Interessierten aus Cottbus und Umgebung. Angesiedelt am FabLab Cottbus (Walther-Pauer-Straße 7), treffen wir uns regelmäßig am letzten Mittwoch im Monat ab 18 Uhr und freuen uns auf neue Gesichter.",
    description_en: nil,
    external_url: "https://chaos-cb.de",
    location: "Walther-Pauer-Straße 7, Cottbus",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=-1WE", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-eisenach",
    title_de: "WAK-Lab Eisenach",
    title_en: nil,
    description_de: "Das <a href=\"https://wak-lab.org\">WAK-Lab</a> ist ein Raum für Hacker, Bastler und technikinteressierte Menschen. Unsere Ziele sind der Aufbau einer offenen Werkstatt, um den Erwerb und das Teilen von technischem Wissen zu fördern. Kontakt über <a href=\"https://matrix.to/#/#wak-lab:im.kabi.tk\">Matrix</a> oder auf unserer Homepage.",
    description_en: nil,
    external_url: "https://wak-lab.org",
    location: "Eisenach",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-erfurt",
    title_de: "Bytespeicher Erfurt",
    title_en: nil,
    description_de: "Der Hackspace Bytespeicher öffnet jeden Mittwoch zum Open Space und trifft sich ab 19 Uhr zum Chaostreff Erfurt in der Liebknechtstraße 8. Wir bieten mit Hackspace, Konferenzraum und Elektronikwerkstatt alle Möglichkeiten zum gemeinsamen Hacken, Lernen, Präsentieren und Experimentieren. Wir unterstützen außerdem Freifunk Erfurt und die Programmier-Initiative Kids@Digital.",
    description_en: nil,
    external_url: "https://www.bytespeicher.org/",
    location: "Liebknechtstraße 8, Erfurt",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-giessen",
    title_de: "Chaostreff Gießen",
    title_en: nil,
    description_de: "Lockerer Treff für alle Chaos-Interessierten aus dem Raum Gießen. Zur Zeit beherbergt uns am ersten Mittwoch des Monats das <a href=\"https://jhrings.de/\">Jhrings Wirtsstuben</a> (Ludwigstraße 10) ab 19 Uhr. An den anderen Mittwochen des Monats treffen wir uns in den Räumlichkeiten von <a href=\"https://mudbyte.de/\">Mudbytes</a>. Um Verwechslungen vorzubeugen, schaut bitte unter <a href=\"https://giessen.ccc.de\">giessen.ccc.de</a> nach dem aktuellen Stand.",
    description_en: nil,
    external_url: "https://giessen.ccc.de",
    location: "Ludwigstraße 10, Gießen",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=1WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-graz",
    title_de: "RealRaum Graz",
    title_en: nil,
    description_de: "Grundsätzlich ist bei den Workshops und sonstigen Veranstaltungen immer jeder willkommen, der Lust hat, was Neues dazuzulernen oder selbst was dazu beizutragen, egal ob Mitglied oder nicht. Ziel ist es, einen chaotisch gemischten Haufen zu schaffen, der fähig ist, sich mit seinen Ideen gegenseitig zu inspirieren. Besonders sind alle willkommen, die bereits bei anderen Vereinen/Initiativen tätig sind (LUGG, STG, Spektral und ähnliches). Die Treffen finden im RealRaum statt.",
    description_en: nil,
    external_url: "https://realraum.at/",
    location: "Graz",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-goeppingen",
    title_de: "Chaostreff Göppingen (SCHAFFEREI)",
    title_en: nil,
    description_de: "Spaß an der Technik haben, kreativ sein, Altes reparieren, Neues generieren, Wissen teilen – gemeinsam macht das Chaos Laune. Der Chaostreff Göppingen findet monatlich in der Göppinger SCHAFFEREI statt. Freifunk, Lötkolben und Mate sind vorhanden.",
    description_en: nil,
    external_url: "https://schafferei.org/chaos-treff/",
    location: "Göppingen",
    events: [
      { rrule: "FREQ=MONTHLY" }
    ],
    review: false
  },
  {
    slug: "chaostreff-gunzenhausen",
    title_de: "Chaostreff Gunzenhausen",
    title_en: nil,
    description_de: "Jeden Dienstag in einer ungeraden Kalenderwoche treffen wir uns ab 19 Uhr im <a href=\"https://fablab-altmuehlfranken.de\">FabLab in Gunzenhausen</a>. Gäste und Interessierte sind gerne willkommen!",
    description_en: nil,
    external_url: "https://chaostreff-gun.de/",
    location: "FabLab Gunzenhausen",
    events: [
      { rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-halle",
    title_de: "Chaostreff Halle (Saale)",
    title_en: nil,
    description_de: "Der Chaostreff trifft sich wöchentlich am Dienstag ab 19 Uhr im <a href=\"https://eigenbaukombinat.de\">Eigenbaukombinat</a> zum Hackerspacetreffen in der Landsberger Straße 3. Reden, tüfteln, hacken inklusive.",
    description_en: nil,
    external_url: "https://eigenbaukombinat.de",
    location: "Landsberger Straße 3, Halle (Saale)",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-hamm",
    title_de: "c3hamm",
    title_en: nil,
    description_de: "Wir, c3hamm, sind seit dem 5.5.2025 Verein. Bauen gerade am HHiC, ein Hackspace &amp; Repair-Cafe zum Mitnehmen im Container. Wir treffen uns regelmässig am 1ten Mittwoch im Monat im Rahmen des eStatischH (Energier-Stammtisch Hamm) VorOrt. Nicht selten treffen wir uns Sonntags zum VRunch inner Brille und erkunden SocialVR Räume, pflegen ein kleines cHaoS-Log: <a href=\"https://y.lab.nrw/c3h-logs\">y.lab.nrw/c3h-logs</a>.",
    description_en: nil,
    external_url: "https://chaos.social/@c3hamm",
    location: "Hamm",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=1WE" }
    ],
    review: false
  },
  {
    slug: "chaostreff-heidelberg",
    title_de: "NoName e.V. Heidelberg",
    title_en: nil,
    description_de: "Wir sind der NoName e.V., ein lustiger zusammengewürfelter Haufen, der sich mindestens einmal pro Woche trifft. Jeder Technikinteressierte ist bei uns gerne gesehen. Der regelmäßige Treff am Donnerstag findet abwechselnd an verschiedenen Orten statt. Infos über spontane Treffen findet man im TWiCEiRC-Channel #chaos-hd.",
    description_en: nil,
    external_url: "https://www.noname-ev.de",
    location: "Heidelberg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-hildesheim",
    title_de: "Freies Labor Hildesheim",
    title_en: nil,
    description_de: "Der Hackerspace „Freies Labor“ ist ein Ort, an dem sich unterschiedliche Disziplinen treffen, kennenlernen und kooperieren. In unserem Labor wollen wir in gemütlicher Atmosphäre gemeinsam tüfteln, kochen, brauen und entdecken. Wir wollen unsere Fähigkeiten und unser Wissen miteinander teilen und stellen Werkstatt, Küche und gemütliche Räume zur Verfügung.",
    description_en: nil,
    external_url: "https://blog.freieslabor.org/",
    location: "Hildesheim",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-hilpoltstein",
    title_de: "Chaostreff Hip Hilpoltstein",
    title_en: nil,
    description_de: "Jeden zweiten Dienstag (ungerade Kalenderwochen) trifft sich der Chaostreff Hip ab 18 Uhr zum gemeinsamen Tüfteln, Reden und Verkosten von Mate im Haus des Gastes (Maria-Dorothea-Straße 8). Interessierte Gäste sind immer herzlich willkommen.",
    description_en: nil,
    external_url: "https://chaos-hip.de/",
    location: "Maria-Dorothea-Straße 8, Hilpoltstein",
    events: [
      { rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-hoher-flaeming",
    title_de: "ge.hackt.es Hoher Fläming",
    title_en: nil,
    description_de: "In Brandenburg, mitten im Wald, gibt es <a href=\"https://ge.hackt.es/\">ge.hackt.es</a>! In unserem Hackspace im Hohen Fläming beschäftigen wir uns nicht ganz zufällig mit Digitalisierung im ländlichen Raum. Wir basteln außerdem Schönes mit Sensoren und bringen ein Repair-Café an den Start. Schreibt uns, wenn ihr den Weg durch den Wald zu uns finden wollt!",
    description_en: nil,
    external_url: "https://ge.hackt.es/",
    location: "Hoher Fläming, Brandenburg",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-ilmenau",
    title_de: "ilmspace Ilmenau",
    title_en: nil,
    description_de: "Wir treffen uns regelmäßig jeden Mittwoch ab 19 Uhr zum <em>open space</em> und einmal im Monat zum Orgatreff. Der Space bietet Raum für alle Chaos-Interessierten aus Ilmenau und Umgebung. Wir helfen euch gern bei Reparaturen, beim Einstieg oder Umstieg in die Linuxwelt oder bei eigenen Projekten. Ihr seid herzlich eingeladen, aktiv unseren Space mitzugestalten. Kontakt via <a href=\"https://matrix.to/#/#SPACE:bau-ha.us\">Matrix</a>.",
    description_en: nil,
    external_url: "http://ilmspace.de/",
    location: "Ilmenau",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-ingolstadt",
    title_de: "bytewerk Ingolstadt",
    title_en: nil,
    description_de: "Am 10. April 2010 wurde in Ingolstadt das <a href=\"http://www.bytewerk.org/\">bytewerk</a> eröffnet, der Hackerspace des Ingolstädter Chaostreff, der aus dem <a href=\"http://www.bingo-ev.de/\">bingo e.V.</a> hervorgegangen ist.",
    description_en: nil,
    external_url: "http://www.bytewerk.org/",
    location: "Ingolstadt",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-innsbruck",
    title_de: "IT-Syndikat Innsbruck",
    title_en: nil,
    description_de: "Das chaosnahe IT-Syndikat ist (mindestens) jeden Dienstag ab 19 Uhr für Besuch offen. Wo? Tschamlerstraße 3, über dem Weekender Club. Sollte unten ein Türsteher-NPC den Weg versperren, kommt man mit einem Verweis auf „die Künstler/Hacker“ immer vorbei.",
    description_en: nil,
    external_url: "http://it-syndikat.org",
    location: "Tschamlerstraße 3, Innsbruck",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-itzehoe",
    title_de: "Computerclub Itzehoe e.V.",
    title_en: nil,
    description_de: "Der Itzehoer Chaostreff ist beim Computerclub Itzehoe e.V. angesiedelt und beschäftigt sich zwanglos mit unterschiedlichsten Hard- und Softwareprojekten. Treffen sind donnerstags ab 19 Uhr.",
    description_en: nil,
    external_url: "http://cciz.de/",
    location: "Itzehoe",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-jena",
    title_de: "Offener Chaostreff Jena (Krautspace)",
    title_en: nil,
    description_de: "Der Offene Chaostreff Jena trifft sich dienstags ab 20 Uhr im Krautspace in der Krautgasse 26.",
    description_en: nil,
    external_url: "https://kraut.space/",
    location: "Krautgasse 26, Jena",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-kiel",
    title_de: "Science Monday Kiel (Toppoint)",
    title_en: nil,
    description_de: "<em>Science Monday - Chaos and more</em> ist der lokale Chaostreff in Kiel. Seit dem ersten Chaostreffen in Kiel finden die Treffen montags ab 19 Uhr in den Räumen der Toppoint statt.",
    description_en: nil,
    external_url: "http://toppoint.de/",
    location: "Kiel",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-klaus-vorarlberg",
    title_de: "Open-Lab Klaus (Vorarlberg)",
    title_en: nil,
    description_de: "Wir treffen uns jeden Dienstag von 16-20 Uhr im <a href=\"https://open-lab.at/index.php/info/location\">Open-Lab</a> in Klaus, Vorarlberg. Ob jung, ob alt, es ist jewesen bei uns willkommen. Wir haben Internet, Werkzeuge, Lötkolben, 3D-Drucker, Sofas und noch einiges mehr zur Verfügung.",
    description_en: nil,
    external_url: "https://open-lab.at/",
    location: "Klaus, Vorarlberg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "16:00", duration_hours: 4 }
    ],
    review: false
  },
  {
    slug: "chaostreff-konstanz",
    title_de: "hacKNology e.V. Konstanz",
    title_en: nil,
    description_de: "Der Chaostreff Konstanz trifft sich jeden 2. Dienstag um 19 Uhr in den Räumlichkeiten des Hackerspace hacKNology e. V.",
    description_en: nil,
    external_url: "https://www.hacknology.de/",
    location: "Konstanz",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=2TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-landau",
    title_de: "CTRL-Z Landau",
    title_en: nil,
    description_de: "<a href=\"https://ctrl-z.info/\">CTRL-Z</a> lädt an drei Dienstagen im Monat zum Open Space bis 23 Uhr ein. Als Teil des <a href=\"https://ztl.space/\">Zentrums für Technikkultur Landau e. V.</a> kann man uns auch bei den zahlreichen Workshops im ZTL treffen. Wir hoffen, ihr schaut mal bei uns vorbei, in der Klaus-Von-Klitzing-Str. 2, im schönen Landau in der Pfalz. Unser Zugang ist barrierefrei, all creatures welcome!",
    description_en: nil,
    external_url: "https://ctrl-z.info/",
    location: "Klaus-Von-Klitzing-Str. 2, Landau",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00", duration_hours: 4 }
    ],
    review: false
  },
  {
    slug: "chaostreff-loerrach",
    title_de: "technik.cafe Lörrach",
    title_en: nil,
    description_de: "Im technik.cafe Lörrach trifft sich monatlich der Chaostreff Lörrach. Dort wird gefachsimpelt, gebastelt, gelernt und ausgetauscht. Es gibt Werkzeug, Komponenten, Lötkolben, Hardware und Netzwerkzubehör zum Basteln, Testen und Reparieren. Betrieben wird das technik.cafe von Privatleuten aus Leidenschaft, es gibt keinen Verein, keine Mitgliedschaft, keine Gebühren.",
    description_en: nil,
    external_url: "https://technik.cafe/",
    location: "Lörrach",
    events: [
      { rrule: "FREQ=MONTHLY" }
    ],
    review: false
  },
  {
    slug: "chaostreff-ludwigsburg",
    title_de: "Chaostreff Ludwigsburg (DemoZ)",
    title_en: nil,
    description_de: "Der Chaostreff Ludwigsburg ist ein lockeres und offenes Zusammentreffen von Menschen, die sich dem CCC und der Hackerethik nahe fühlen. Wir treffen uns am letzten Donnerstag im Monat ab 18:00 Uhr im DemoZ in Ludwigsburg und ständig bei <a href=\"https://matrix.to/#/#chaostreff-lb:matrix.org\">Matrix</a>.",
    description_en: nil,
    external_url: "https://complb.de",
    location: "DemoZ, Ludwigsburg",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=-1TH", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-luxemburg",
    title_de: "CCC Lëtzebuerg",
    title_en: nil,
    description_de: "Der Chaos Computer Club Lëtzebuerg trifft sich jeden Montag um 20 Uhr in der Hauptstadt Luxemburgs im Hackerspace ChaosStuff. Interessierte sind jederzeit herzlich willkommen, zu unseren Treffen zu kommen.",
    description_en: nil,
    external_url: "http://www.c3l.lu/",
    location: "Luxemburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-marburg",
    title_de: "Hackspace Marburg (hsmr)",
    title_en: nil,
    description_de: "Der Chaostreff Marburg findet jeden Montag ab 18:00 Uhr im <a href=\"https://hsmr.cc/\">Hackspace Marburg</a> statt. Aber auch sonst lohnt ein Besuch des [hsmr] immer. Erreichen könnt Ihr uns über die <a href=\"https://hsmr.cc/Infrastruktur/Mailinglisten\">Mailingliste</a> oder im IRC auf hackint #hsmr.",
    description_en: nil,
    external_url: "https://hsmr.cc/",
    location: "Marburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-markdorf",
    title_de: "Toolbox Bodensee e.V. Markdorf",
    title_en: nil,
    description_de: "Der Chaostreff Markdorf trifft sich regelmäßig im Hackerspace Toolbox Bodensee e. V. Alle galaktischen Wesen sind willkommen.",
    description_en: nil,
    external_url: "https://bodensee.space/chaostreff-markdorf",
    location: "Markdorf",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-muenster",
    title_de: "warpzone Münster",
    title_en: nil,
    description_de: "Das Chaos in Münster trifft sich jeden Mittwoch ab 19 Uhr in der warpzone, 51.943374° N, 7.638241° E.",
    description_en: nil,
    external_url: "http://www.warpzone.ms/",
    location: "Münster",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-neuss",
    title_de: "fnordeingang e.V. Neuss",
    title_en: nil,
    description_de: "Der Chaostreff Neuss findet jeden Mittwoch ab 19 Uhr in den Räumen des fnordeingang e. V. statt. Jeder ist herzlich willkommen, es wird keine Anmeldung benötigt.",
    description_en: nil,
    external_url: "https://fnordeingang.de/chaostreff",
    location: "Neuss",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-nuernberg",
    title_de: "Chaostreff Nürnberg",
    title_en: nil,
    description_de: "Der Chaostreff Nürnberg trifft sich abwechselnd im Hackerspace K4CG und Nerdberg.",
    description_en: nil,
    external_url: "https://chaostreff-nuernberg.de",
    location: "Nürnberg",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-osnabrueck",
    title_de: "Chaostreff Osnabrück",
    title_en: nil,
    description_de: "Der Chaostreff Osnabrück ist eine lockere Gruppe von Leuten mit Interesse in den Bereichen Sicherheit, Kryptographie, alternative Betriebssysteme, freie Software, Netzpolitik und vielen weiteren Themen. Interessierte sind jederzeit herzlich willkommen, zu unseren Treffen zu kommen.",
    description_en: nil,
    external_url: "https://chaostreff-osnabrueck.de/",
    location: "Osnabrück",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-potsdam",
    title_de: "Chaostreff Potsdam (machBar)",
    title_en: nil,
    description_de: "Der Chaostreff Potsdam trifft sich jeden Mittwoch um 19 Uhr. Die Treffen finden in den Räumen des Hackerspace machBar im freiLand, Friedrich-Engels-Straße 22, Haus 5 statt. Alle galaktischen Lebensformen sind willkommen.",
    description_en: nil,
    external_url: "https://www.ccc-p.org/",
    location: "Friedrich-Engels-Straße 22, Haus 5, Potsdam",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-rapperswil",
    title_de: "Coredump Rapperswil-Jona",
    title_en: nil,
    description_de: "(Fast) jeden Montag treffen wir uns ab 20 Uhr im <a href=\"https://www.coredump.ch/der-hackerspace/\">Hackerspace Coredump</a> auf dem Vinora-Areal in Jona (Schweiz) zur wöchentlichen „Hacknight“. Wie bei all unseren Events sind Gäste dabei herzlich willkommen. Mit Ferienpass-Kursen und regelmäßigen Rust-Meetups engagiert sich der Verein Coredump auch in der Kinder- und Erwachsenen-Bildung.",
    description_en: nil,
    external_url: "https://www.coredump.ch/",
    location: "Vinora-Areal, Jona",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-recklinghausen",
    title_de: "Chaostreff Recklinghausen (Hackerhütte)",
    title_en: nil,
    description_de: "Jeden Mittwoch trifft sich der Chaostreff Recklinghausen in der Hackerhütte, Westcharweg 101, 45659 Recklinghausen.",
    description_en: nil,
    external_url: "http://c3re.de",
    location: "Westcharweg 101, 45659 Recklinghausen",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-regensburg",
    title_de: "Binary Kitchen Regensburg",
    title_en: nil,
    description_de: "Regensburg hackt in der <a href=\"http://binary.kitchen\">Binary Kitchen</a>. Immer montags. Offen für alle.",
    description_en: nil,
    external_url: "http://binary.kitchen",
    location: "Regensburg",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-rodgau",
    title_de: "Chaostreff Rodgau",
    title_en: nil,
    description_de: "Wir haben Anfang 2025 einen Chaostreff Rodgau gegründet. Wir treffen uns einmal im Monat an unterschiedlichen Orten. Termin und Ort werden auf unserer Website bekanntgegeben.",
    description_en: nil,
    external_url: "https://chaostreff-rodgau.codeberg.page",
    location: "Rodgau",
    events: [
      { rrule: "FREQ=MONTHLY" }
    ],
    review: false
  },
  {
    slug: "chaostreff-rotterdam",
    title_de: "Chaostreff Rotterdam (Pixelbar)",
    title_en: "Chaostreff Rotterdam (Pixelbar)",
    description_de: "The Chaostreff of Rotterdam meets every Wednesdays around 20 Uhr at Pixelbar in the Keilewerf at the Vierhavensstraat 56 in Rotterdam close to RET / Metro station Marconiplein.",
    description_en: "The Chaostreff of Rotterdam meets every Wednesdays around 20 Uhr at Pixelbar in the Keilewerf at the Vierhavensstraat 56 in Rotterdam close to RET / Metro station Marconiplein.",
    external_url: "https://www.pixelbar.nl/contact/",
    location: "Vierhavensstraat 56, Rotterdam",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-saarbruecken",
    title_de: "hacksaar Saarbrücken",
    title_en: nil,
    description_de: "Unser regelmäßiges Treffen findet jeden Mittwoch ab 19 Uhr im h´eck in der Rathausstraße 18 in 66125 Saarbrücken statt. Gäste und Interessierte sind immer gerne willkommen.",
    description_en: nil,
    external_url: "https://www.hacksaar.de",
    location: "Rathausstraße 18, 66125 Saarbrücken",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-schwerin",
    title_de: "Hacklabor Schwerin",
    title_en: nil,
    description_de: "Bist Du interessiert an Computerkrams, Programmieren, Capture-the-Flag-Challenges, 3D-Druckern, CO2-Lasern, Microcontrollern, Automatisierung, gesellschaftlichen Auswirkungen von Technik und Spaß am Gerät? Hat es Dich nach Mecklenburg-Vorpommern verschlagen? Dann komm ins Hacklabor in der Hagenower Straße 73, Schwerin. In unserer offenen Werkstatt findet sich vom Lötkolben bis zum 3D-Drucker alles, was das Makerherz höher schlagen lässt. Jugendlichen bieten wir im \"Jugend hackt Lab\" die Möglichkeit, Neues auszuprobieren und kreative Ideen zu verwirklichen. Unsere Treffen sind öffentlich und finden mittwochs und freitags ab 19 Uhr statt.",
    description_en: nil,
    external_url: "https://hacklabor.de/",
    location: "Hagenower Straße 73, Schwerin",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE,FR", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-trier",
    title_de: "Maschinendeck e.V. Trier",
    title_en: nil,
    description_de: "Mit dem Maschinendeck e. V. haben wir uns zum Ziel gesetzt, in Trier einen Ort zu schaffen, wo alle Arten von Nerdkultur ein Zuhause finden können. Ob Du coden, löten, Kaffee rösten, Brettspiele spielen oder Deine neueste Verschwörungstheorie besprechen willst: Im Maschinendeck gibt es einen Platz für Dich. Das wöchentliche Treffen findet jeden Mittwoch, 20 Uhr, in unseren Räumen statt.",
    description_en: nil,
    external_url: "http://www.maschinendeck.org",
    location: "Trier",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=WE", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-tuebingen",
    title_de: "Chaostreff Tübingen",
    title_en: nil,
    description_de: "Der Chaostreff Tübingen ist eine lockere Sammlung zumeist Tübinger und Reutlinger Chaos. Wir treffen uns regelmäßig am letzten Sonntag im Monat gegen 18:00 Uhr im <a href=\"https://ki-maker.space/\">KIMS</a> und ungefähr jeden 2. Montag im Monat gegen 19:00 Uhr im <a href=\"https://www.fablab-neckar-alb.org/\">FabLab</a>. Beide Orte glücklicherweise gut zu Fuß vom Bahnhof erreichbar.",
    description_en: nil,
    external_url: "https://cttue.de",
    location: "Tübingen",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=-1SU", start_time: "18:00",
        location: "KIMS, Tübingen" },
      { rrule: "FREQ=MONTHLY;BYDAY=2MO", start_time: "19:00",
        location: "FabLab Neckar-Alb, Tübingen" }
    ],
    review: false
  },
  {
    slug: "chaostreff-villingen-schwenningen",
    title_de: "vspace.one Villingen-Schwenningen",
    title_en: nil,
    description_de: "Der Chaostreff Villingen-Schwenningen ist Treffpunkt für alle Chaosnahen aus dem Raum Schwarzwald-Baar. Er ist dem Maker- / Hackerspace vspace.one angeschlossen. Jeden Dienstag ab 19 Uhr finden öffentliche Treffen zur Wissensförderung in der Wilhelm-Binder-Straße 19 in Villingen statt. Für gemütliche Plätze, coole Atmosphäre und Mate ist gesorgt!",
    description_en: nil,
    external_url: "http://vspace.one",
    location: "Wilhelm-Binder-Straße 19, Villingen-Schwenningen",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "19:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-waldkraiburg",
    title_de: "Chaostreff Waldkraiburg",
    title_en: nil,
    description_de: "Der Chaostreff Waldkraiburg ist eine dem Chaos Computer Club zugehörige Gruppe und Anlaufstelle für alle chaosnahen und interessierten Wesen für die Landkreise Mühldorf am Inn, Altötting und darüber hinaus. Wir sind technikbegeisterte Menschen und beschäftigen uns mit IT-Sicherheit, Webdesign, Gaming, alternativen Betriebssystemen, Retrocomputing, freier Software, Netzpolitik und vielen weiteren Themen. Ob Anfänger oder Profi spielt keine Rolle, es ist keine Anmeldung erforderlich.",
    description_en: nil,
    external_url: "https://c3wkb.de",
    location: "Waldkraiburg",
    events: [],
    review: false
  },
  {
    slug: "chaostreff-westerwald",
    title_de: "Westwoodlabs Westerwald",
    title_en: nil,
    description_de: "Der Chaostreff Westerwald trifft sich jeden Dienstag um 18 Uhr für alle Interessierten in den Räumen der Westwoodlabs in Ransbach-Baumbach.",
    description_en: nil,
    external_url: "https://westwoodlabs.de/",
    location: "Ransbach-Baumbach",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TU", start_time: "18:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-wuppertal",
    title_de: "Chaostreff Wuppertal (chaostal)",
    title_en: nil,
    description_de: "Der Chaostreff unter der Schwebebahn organisiert in regelmäßigen Abständen Treffen zum gegenseitigen Austausch. Neue Besucher sind jederzeit willkommen. Treffen finden jeden ersten Donnerstag im Monat ab 20 Uhr im Mirker Bahnhof, Mirker Straße 48, Wuppertal-Elberfeld statt. An allen anderen Donnerstagen wechselt der Ort.",
    description_en: nil,
    external_url: "https://www.chaostal.de/category/meeting",
    location: "Mirker Straße 48, Wuppertal-Elberfeld",
    events: [
      { rrule: "FREQ=MONTHLY;BYDAY=1TH", start_time: "20:00" }
    ],
    review: false
  },
  {
    slug: "chaostreff-zwickau",
    title_de: "z-Labor Zwickau",
    title_en: nil,
    description_de: "Für alle chaosnahen Lebewesen öffnet das z-Labor donnerstags um 19 Uhr die Räumlichkeiten in der <a href=\"https://osm.org/go/0MCmr_jJo\">Kulturweberei</a> zum kollektiven Hacken, Basteln, Lernen und Philosophieren. Wir mögen Freie Software, IT-Sicherheit, (Analog-)Fotografie, 3D-Druck, Mate und viele Formen von (digitaler) Kunst. Neben Elektroniklabor und Rechentechnik gibt es eine Holz- und Metallwerkstatt, eine Musik-Ecke und einen Retro-Spiel-Bereich.",
    description_en: nil,
    external_url: "https://www.z-labor.space",
    location: "Kulturweberei, Zwickau",
    events: [
      { rrule: "FREQ=WEEKLY;BYDAY=TH", start_time: "19:00" }
    ],
    review: false
  }
]

chaostreffs.each do |entry|
  seed_chapter(parent_id: 549, tag: "chaostreff-detail", **entry)
end

puts "Done."
puts "Nodes flagged for review:"
(erfas + chaostreffs).select { |e| e[:review] }.each do |e|
  puts "  #{e[:slug]}"
end

Node.rebuild!(false)

