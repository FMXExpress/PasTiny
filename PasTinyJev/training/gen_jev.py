"""Synthetic typed-decision data for PasTinyJev (support-message triage).

Every example is a short customer message (the *state*) with known hidden
properties (topic, tone, urgency ...), plus typed questions about it.  The
labels are true by construction; a few are deliberately soft so the model
learns to say "not sure".

Wire format, one *read* per line of the model's context (128 letters at most):

    noul            state|instruction<NL>          -> next letter y / n
    choice, score   state|instruction:option<NL>   -> next letter y / n

A choice or score is one read per option; the y-minus-n scores of the options
go through a softmax.  `python3 gen_jev.py` prints samples.
"""
import random
import re

MAXLEN = 127          # letters before the final newline token
STATEMAX = 80         # the runtime keeps at most this much of a state
HEAD, TAIL = 53, 26   # a longer state keeps its first 53 and last 26 letters

# ------------------------------------------------------------------ grammar
_ALT = re.compile(r'\{([^{}]*)\}')


def expand(rng, s):
    """'{a|b|c}' -> one of a, b, c (nesting allowed)."""
    while True:
        m = _ALT.search(s)
        if not m:
            return s
        s = s[:m.start()] + rng.choice(m.group(1).split('|')) + s[m.end():]


# ------------------------------------------------------------------ topics
# name -> (option wordings, message cores).  Cores at index % 5 == 4 are never
# trained on (held-back test wordings).
TOPICS = {
    'billing': (
        ['billing', 'payments', 'charges, refunds', 'money', 'invoices', 'billing team', 'charges'],
        [
            'i was {charged|billed} twice {this month|for my plan|on my card}',
            'my {invoice|bill|receipt} {is|looks} wrong',
            '{can|could} i get a refund{?| please?| for last month?}',
            'you {charged|billed} me for a plan i {cancelled|never ordered|do not use}',
            'the invoice looks wrong again',
            'why {was i|did you} charge{d|} {me |}{$20|$49|$99|extra}?',
            'i want my money back',
            'my card was {declined|charged twice|billed twice}',
            '{there is|i see} a {strange|wrong|double} charge on my {card|account|statement}',
            'refund {still|has} not {arrived|come through|shown up}',
            'the {price|amount|total} on my {bill|invoice} is {too high|wrong|not right}',
            'how do i {update|change} my {card|payment method|billing details}?',
            'i {paid|already paid} but it {says|still says} unpaid',
            'please {send|email} me {an|the|my} invoice for {march|june|last month|this year}',
            'the {discount|coupon|promo code} did not {apply|work} to my {bill|order|payment}',
            'need a {receipt|vat invoice|tax invoice} for my {payment|purchase|subscription}',
            'you took {money|a payment} {twice|two times} from my {bank|card|account}',
            'overcharged {again|this month|by $10}, please {fix|correct} my bill',
            'what is this {$5|$30|extra} fee on my {bill|invoice|statement}?',
            'my {payment|transfer} {failed|did not go through} but the money is gone',
        ]),
    'outage': (
        ['outage', 'service down', 'incidents', 'downtime', 'site is down', 'ops', 'errors, downtime'],
        [
            '{everything|the site|the app|the api|the server} is down',
            '{the site|the app|your service|the dashboard} is not {loading|working|responding}',
            'we {are getting|keep getting|see} {500|502|503} errors {everywhere|on every page|on all requests}',
            'the {whole |}{system|platform|service} {went|is} {down|offline}',
            '{nothing|no page} {loads|works} {right now|since this morning|for our users}',
            'the api {is timing out|returns errors|times out} for {all|every} {requests|calls}',
            'is the {service|site|server} down? {nothing|no page} {works|loads}',
            'our {whole team|customers|users} {cannot|can not} {reach|use|open} the {app|site|service}',
            'the {app|website} {crashes|keeps crashing|freezes} {on start|every time|for everyone}',
            '{servers are|database is|the site is} {unreachable|offline|down} {again|since 9am|for an hour}',
            'getting {connection refused|a blank page|gateway timeout} on {the site|every page|the app}',
            'the {service|app|dashboard} has been {down|broken|dead} {all day|for hours|since last night}',
            'production is {down|broken|on fire}',
            '{huge|major|total} outage, {nothing|none of it} {works|is working}',
            'the {status page|site|app} shows {errors|an outage|nothing at all}',
            'all our {pages|requests|jobs} are {failing|timing out|erroring}',
            'your {servers|systems} are {down|not responding} {again|right now}',
            'site {down|unreachable|offline}',
            'cannot {load|open|reach} {anything|any page|the app}, is there an outage?',
            'the {app|service} stopped working for {everyone|all of us|the whole office}',
        ]),
    'login': (
        ['login', 'account access', 'passwords', 'sign in problems', 'accounts', 'password, sign in', 'access'],
        [
            'i {cannot|can not|am unable to} {log in|sign in|get into my account}',
            'i forgot my password',
            'how do i reset my password?',
            'the {reset|password reset} {email|link} {never arrived|does not work|has expired}',
            'my account is locked',
            'it says {wrong password|invalid login|unknown user} but {it is right|i am sure it is correct}',
            '{two factor|2fa|the login} code {never comes|is not arriving|does not work}',
            'i {lost|changed} my phone and {cannot|can not} {log in|sign in} {now|anymore}',
            'locked out of my account {again|since monday|after the update}',
            'please {unlock|reset|recover} my account',
            'the {sign in|login} page {keeps|just} {rejecting|refusing} my password',
            'can you {change|update} the email on my account?',
            'i need to {recover|get back into} my {old |}account',
            'my {username|email} is not {recognised|accepted|found} at {login|sign in}',
            'password reset is {broken|not working|stuck}',
            'cannot sign in with {google|my email|sso}',
            'the login {form|screen} {logs me out|kicks me out|loops} right away',
            'someone {changed|reset} my password, i {cannot|can not} get in',
            'how do i {sign in|log in} on a new {phone|laptop|device}?',
            'my {login|sign in} {fails|stopped working} since {yesterday|the update|this morning}',
        ]),
    'shipping': (
        ['shipping', 'delivery', 'orders, parcels', 'late deliveries', 'shipping team', 'parcels', 'orders'],
        [
            'my {order|parcel|package} {has not arrived|is late|never came}',
            'where is my {order|parcel|package}?',
            'the {tracking|tracking number|tracking link} {does not work|shows nothing|has not moved}',
            'i {got|received} the wrong {item|size|colour|product}',
            'my {package|parcel|box} arrived {damaged|broken|open|crushed}',
            'when will my order {ship|arrive|be delivered}?',
            'the {courier|driver} {never came|left it outside|lost my parcel}',
            'order {4412|8830|1207} is {still|} {not here|missing|stuck in transit}',
            '{one|an} item is missing from my {order|parcel|box}',
            'can i change the {delivery|shipping} address{?| on my order?}',
            'it has been {two|three|four} weeks and {no parcel|nothing arrived|still no delivery}',
            'my order was {sent|delivered|shipped} to the wrong {address|house|city}',
            'how {long|much} {does|is} {shipping|delivery} {take |}to {canada|spain|japan}?',
            'the parcel says delivered but i {have nothing|never got it|did not get it}',
            'please {send|ship} my order {faster|by express|again}',
            'i want to return {this|the} {item|order|shoes}, how do i send it back?',
            'delivery is {very |}{late|delayed|overdue}',
            'the box came {empty|wet|ripped}',
            'still waiting for my {delivery|order|parcel}',
            'do you {ship|deliver} to {norway|brazil|india}?',
        ]),
    'feature': (
        ['feature', 'feature requests', 'requests, how-to', 'product ideas', 'how-to', 'ideas', 'product team'],
        [
            '{can|could} you add {dark mode|an export button|csv export|a mobile app}?',
            'it would be {nice|great|good} to have {dark mode|folders|tags|a calendar view}',
            'how do i {export|share|print|rename} {a report|my data|a project}?',
            'please add {support for|an option for} {pdf|two languages|keyboard shortcuts|teams}',
            'is there a way to {sort|filter|search|group} {by date|my list|the table}?',
            'feature request: {bulk edit|undo|offline mode|bigger fonts}',
            'do you {have|plan} {an api|a mac app|a plugin|an android app}?',
            'i wish {the app|it|the editor} had {spell check|templates|a timer|reminders}',
            'can the {report|dashboard|chart} show {weekly|monthly|daily} {totals|numbers|views}?',
            'where {is|do i find} the {settings|export|import|share} {page|menu|button}?',
            'an idea: let {users|us|me} {pin|star|colour|archive} {items|notes|projects}',
            'would love {a dark theme|shortcuts|an undo button|a search box}',
            'how can i {invite|add|remove} a {teammate|user|member}?',
            'suggestion: {add|make} {a way to|it possible to} {duplicate|merge|copy} {pages|projects}',
            'does the {app|tool|product} {support|work with|connect to} {slack|excel|outlook}?',
            'could the {list|page|table} {remember|keep|save} my {filters|sort order|view}?',
            'any plans for {a linux version|voice notes|a public api|widgets}?',
            'how do i turn {on|off} {notifications|email alerts|auto save}?',
            'it needs a {better|faster|simpler} {search|editor|menu}',
            'please let me {change|pick|set} the {font|colour|language|time zone}',
        ]),
    'praise': (
        ['praise', 'compliments', 'happy feedback', 'thanks', 'positive feedback', 'kind words', 'thank you notes'],
        [
            'i {love|really like|adore} {the app|your product|the new update|this tool}',
            'great {job|work|service}{!|, team!|, thank you!}',
            'thanks{,|} {the support was|you were|anna was} {great|so helpful|very kind|fantastic}',
            '{best|nicest|fastest} {support|service|app} i have {ever |}{used|had|seen}',
            'just wanted to say {thank you|thanks|well done|you rock}',
            'the new {version|update|design} is {amazing|wonderful|so good|brilliant}',
            'your team {solved|fixed} {it|my problem|everything} in {minutes|no time}, {thanks|thank you}',
            '{five|5} stars, {keep it up|love it|very happy}',
            'really {happy|pleased|impressed} with {the service|your help|the product}',
            'you {guys|people|folks} are {awesome|the best|great}',
            'this {app|tool|service} {saved|saves} me {hours|so much time|every week}',
            'fantastic {product|update|experience}, {well done|thank you|good work}',
            'so {glad|happy} i {found|chose|switched to} {you|this app|your service}',
            'kudos to {the|your} {team|support staff|developers}',
            'works {perfectly|like a charm|beautifully}, {thanks|thank you|great job}',
            'what a {lovely|great|smooth} {app|experience|service}',
            'a big thank you to {mark|your team|support|the whole crew}',
            'everything is {perfect|great|working great}, {nice work|good job|thanks}',
            'i am a {happy|very happy|delighted} customer',
            'the {help|answer|reply} was {quick|fast} and {friendly|clear|kind}, thanks',
        ]),
    'spam': (
        ['spam', 'junk', 'ads, scams', 'junk mail', 'scam', 'spam, ads', 'unwanted ads'],
        [
            '{win|claim} a free {iphone|cruise|gift card|tv} {now|today}, click here',
            'cheap {pills|watches|loans|followers}, {best|lowest} {price|prices} {online|ever}',
            'you {have won|are the winner of|won} {$1000|a prize|the lottery}{!|, claim now!}',
            'buy {10000 |}{followers|likes|backlinks} for {$5|$9|cheap}',
            '{hot|lonely} singles {near you|in your area} want to {chat|meet}',
            'make {$500|$900|money} a day {from home|online|with no work}',
            'limited offer: {90|70|80}% off {designer bags|sunglasses|all watches}',
            'dear friend, i am a prince and need your {help|bank details|account}',
            'boost your {seo|website traffic|sales} {now|fast} with our {cheap |}service',
            'click {this|the} link to {get|claim|unlock} your {reward|bonus|free coins}',
            'earn {bitcoin|crypto|cash} fast, {no risk|guaranteed|join now}',
            'we sell {email lists|fake reviews|cheap traffic}, reply for prices',
            'congratulations, you {were|have been} {selected|chosen} for a free {gift|trial|phone}',
            'lose {10|20|30} pounds in a week with this {trick|pill|tea}',
            'casino bonus: {100|200|500} free spins, {play|join|sign up} now',
            'get a loan {today|now|in 5 minutes}, no {credit check|questions|papers}',
            'special deal just for you, visit {our shop|this site|the link} now',
            'free {money|gift card|crypto} for the first {100|50} {users|people} who click',
            'your {pc|computer} has a virus, call this number now',
            'work from home and earn {big|fast|$3000 a week}',
        ]),
    'cancel': (
        ['cancel', 'cancellations', 'closing accounts', 'cancel, unsubscribe', 'retention', 'leaving', 'unsubscribe'],
        [
            'i want to cancel my {subscription|plan|account|membership}',
            'please {cancel|close|delete} my account',
            'how do i {cancel|unsubscribe|close my account}?',
            'stop {sending me emails|my subscription|the renewal}',
            'i {no longer|do not} need {this|the service|my plan}, {cancel it|please cancel}',
            'unsubscribe me {from everything|from the list|now}',
            'do not renew my {plan|subscription|membership}',
            'i am {leaving|switching to another tool|done with this app}, {close|cancel} my account',
            'please {end|stop} my {trial|plan|contract} {today|this month|before it renews}',
            'how {can|do} i {delete|remove|erase} my {account|profile|data}?',
            'cancel {my|our} {order|subscription|membership} {please|right away|today}',
            'we are moving to {another|a different} {provider|product}, please close {us|our account}',
            'take me off your {mailing list|newsletter|emails}',
            'i would like to {downgrade|pause|stop} my {plan|subscription}',
            'want to {quit|leave|opt out}, how do i {cancel|do that}?',
            'remove my {card|details} and {close|delete} the account',
            'turn off auto {renew|renewal|billing} and {end|cancel} my plan',
            'i {never|rarely} use it, {so |}please cancel',
            'delete {everything|all my data} and close my account',
            'can i cancel {any time|before the trial ends|without a fee}?',
        ]),
}
TOPIC_NAMES = list(TOPICS)

# ------------------------------------------------------------------ tone
TONE_PRE = {
    0: ['', '', '', 'hi, ', 'hello, ', 'hi there, ', 'hey, ', 'good morning, ', 'quick question: '],
    1: ['', '', 'ugh, ', 'come on, ', 'seriously, ', 'not happy: ', 'again: ', 'sigh, '],
    2: ['', '', 'what the hell, ', 'unbelievable! ', 'this is a joke, ', 'for the last time, ', 'wow. '],
}
TONE_POST = {
    0: ['', '', '.', '. thanks', '. thank you', ', please advise', '. cheers', ', thanks!', '. many thanks',
        '. could you help?', ', please'],
    1: ['. this is {annoying|frustrating|getting old}', ', again', '. not {happy|impressed|great}',
        '. {second|third} time this {week|month|quarter}', '. i am {annoyed|not happy|a bit fed up}',
        '. it keeps happening', '. this is {tiring|a pain|disappointing}', ', what is going on',
        '. please sort it out'],
    2: ['!!!', '. this is {ridiculous|unacceptable|outrageous}!', '. worst {service|support|company} ever',
        '. i am {furious|livid|so angry}', '! fix it or i {leave|cancel|sue}', '. absolutely {useless|pathetic}!',
        '!! i have had enough', '. total {disgrace|joke|garbage}!', '. i am {done|sick of this}!!'],
}
TONE_WORDS = [
    ['calm', 'fine', 'relaxed', 'neutral', 'not upset', 'ok'],
    ['annoyed', 'irritated', 'unhappy', 'frustrated', 'a bit upset'],
    ['furious', 'very angry', 'enraged', 'livid', 'outraged'],
]

# ------------------------------------------------------------------ urgency
URG_POST = {
    0: [' no rush', ' whenever you can', ' not urgent', ' no hurry', ' it can wait', ' when you have time',
        ' low priority'],
    1: [''],
    2: [' asap', ' urgent', ' need this {fixed |}{today|now|within the hour|by noon}', ' right away',
        ' we have a {demo|launch|deadline} {at noon|today|in an hour}', ' this is urgent',
        ' please hurry', ' it cannot wait', ' i need help now', ' {clients|customers} are waiting'],
}
URG_WORDS = [
    ['low', 'can wait', 'not urgent', 'whenever'],
    ['normal', 'medium', 'soon', 'this week'],
    ['high', 'urgent', 'right now', 'critical'],
]


# ------------------------------------------------------------------ states
class State:
    __slots__ = 'text topic tone urg core_id'.split()


def clean(s):
    """Lower case, printable ASCII, and the two separator letters removed."""
    s = ''.join(c if ' ' <= c <= '~' else ' ' for c in s.lower())
    s = s.replace('|', '/').replace('\n', ' ')
    return re.sub(r' +', ' ', s).strip()


def make_state(rng, held=False, maxlen=84):
    """held=False: training wordings.  held=True: the held-back cores only."""
    while True:
        st = State()
        st.topic = rng.choice(TOPIC_NAMES)
        cores = TOPICS[st.topic][1]
        ids = [i for i in range(len(cores)) if (i % 5 == 4) == held]
        st.core_id = rng.choice(ids)
        if st.topic in ('praise', 'spam'):
            st.tone, st.urg = 0, 1
        else:
            st.tone = rng.choice([0, 0, 1, 1, 2])
            st.urg = rng.choice([0, 1, 1, 1, 2, 2])
        core = expand(rng, cores[st.core_id])
        if st.topic in ('praise', 'spam'):
            text = core
        else:
            pre = rng.choice(TONE_PRE[st.tone])
            post = expand(rng, rng.choice(TONE_POST[st.tone]))
            urg = expand(rng, rng.choice(URG_POST[st.urg]))
            if core[-1] in '?!' and post[:1] in '.,!':
                post = post[1:] if post[:1] == '!' else ' ' + post[1:].strip() if len(post) > 1 else ''
            if urg and rng.random() < 0.5:
                text = pre + core + ',' + urg + post
            else:
                text = pre + core + post + ('.' + urg if urg and post and post[-1] not in '.!?' else urg)
        text = clean(text)
        if rng.random() < 0.03 and len(text) > 8:          # a typo now and then
            i = rng.randrange(1, len(text) - 1)
            text = text[:i] + text[i + 1:]
        if len(text) <= maxlen:
            st.text = text
            return st


def fit_state(text):
    """What JEV.EXE does to a state: clean it, and keep head + tail if too long."""
    text = clean(text)
    if len(text) > STATEMAX:
        text = text[:HEAD] + ' ' + text[-TAIL:]
    return text


def fit_text(text):
    """Instructions and options: cleaned, no ':' and no final '?' or '.'."""
    return clean(text.replace(':', ',')).rstrip('?. ')


def compose(q):
    """Model contexts for one API-style question dict (state, type, instructions,
    criteria).  Returns (lines, option names)."""
    st, instr, kind = fit_state(q['state']), fit_text(q['instructions']), q['type']
    if kind == 'noul':
        return [read_line(st, instr)], None
    crit = q['criteria']
    if isinstance(crit, dict):                     # choice: name -> description
        names = list(crit)
        opts = [fit_text(crit[n] or n) for n in names]
    else:                                          # score: ordered levels
        names = list(range(len(crit)))
        opts = [fit_text(c) for c in crit]
    return [read_line(st, instr, o) for o in opts], names


# ------------------------------------------------------------------ questions
# Wordings at index % 4 == 3 are never trained on.
def _split(items, held):
    return [w for i, w in enumerate(items) if (i % 4 == 3) == held]


def p_urgent(st):
    if st.topic in ('praise', 'spam'):
        return 0.02
    if st.urg == 2:
        return 0.98
    if st.urg == 0:
        return 0.03
    return 0.6 if st.topic == 'outage' else 0.2


def p_upset(st):
    return (0.04, 0.9, 0.99)[st.tone]


def p_furious(st):
    return (0.01, 0.12, 0.97)[st.tone]


NOULS = [
    (['is this urgent', 'urgent', 'does this need a reply within the hour', 'needs a fast reply',
      'is it time sensitive', 'does the customer need a reply now', 'is this high priority',
      'should we answer right away'], p_urgent),
    (['can this wait', 'is it fine to reply later', 'not urgent', 'is this low priority',
      'can we answer tomorrow'], lambda st: 1 - p_urgent(st)),
    (['is the customer upset', 'is the user unhappy', 'upset customer', 'is the writer annoyed or angry',
      'is the customer unhappy', 'does the customer sound upset', 'is the tone negative',
      'is this an unhappy customer'], p_upset),
    (['is the customer calm', 'is the tone calm', 'calm customer', 'is the writer relaxed',
      'does the customer sound calm'], lambda st: 1 - p_upset(st)),
    (['is the customer furious', 'is the user very angry', 'furious customer', 'is the writer enraged',
      'is the customer extremely angry', 'does the customer sound furious'], p_furious),
    (['is this spam', 'spam', 'is this junk mail', 'is this an ad or a scam', 'is the message spam',
      'should this go to the spam folder'], lambda st: 0.99 if st.topic == 'spam' else 0.01),
    (['is this a real customer message', 'is this a genuine request', 'not spam', 'is this from a real user'],
     lambda st: 0.02 if st.topic == 'spam' else 0.98),
    (['does the customer ask a question', 'is there a question', 'contains a question',
      'is the customer asking something', 'does the message have a question'],
     lambda st: 0.97 if '?' in st.text else 0.05),
    (['is this praise', 'is this a compliment', 'is the customer happy', 'positive feedback',
      'is the customer pleased', 'is this a thank you note'],
     lambda st: 0.99 if st.topic == 'praise' else 0.01),
    (['does the customer want to leave', 'is this a cancellation', 'does the user want to cancel',
      'churn risk', 'is the customer leaving'],
     lambda st: 0.98 if st.topic == 'cancel' else 0.03),
    (['is something broken', 'is this a problem report', 'is the customer reporting a fault',
      'is something not working', 'is this a complaint about a fault'],
     lambda st: {'outage': 0.98, 'login': 0.8, 'billing': 0.5, 'shipping': 0.6}.get(st.topic, 0.03)),
]
TOPIC_NOUL = ['is this about {o}', 'is it a {o} issue', 'is this a {o} problem', '{o}', 'about {o}',
              'does this belong to {o}', 'should {o} handle this', 'is the topic {o}']
TOPIC_CHOICE = ['which team should handle it', 'what is this about', 'topic', 'category', 'which team',
                'route to', 'department', 'what kind of message is this', 'who should get this',
                'pick the topic', 'what is the customer writing about']
TONE_CHOICE = ['how upset is the customer', 'tone', 'mood', 'how does the customer feel',
               'how angry is the customer', 'what is the tone', 'customer mood', 'how does the writer sound']
URG_CHOICE = ['how urgent is this', 'priority', 'urgency', 'how fast should we reply',
              'how soon must we answer', 'what priority is this']


def read_line(state, instr, option=None):
    return state + '|' + instr + ('' if option is None else ':' + option)


def make_question(rng, st, held=False):
    """One typed question about `st`.

    Returns (kind, lines, target) where `lines` is one model context per read
    and `target` is P(yes) for a noul or a probability per option otherwise."""
    r = rng.random()
    if r < 0.34:                                   # plain yes/no
        words, fn = rng.choice(NOULS)
        instr = rng.choice(_split(words, held) or words)
        return 'noul', [read_line(st.text, instr)], fn(st)
    if r < 0.44:                                   # yes/no about one topic
        t = st.topic if rng.random() < 0.5 else rng.choice(TOPIC_NAMES)
        o = rng.choice(_split(TOPICS[t][0], held))
        instr = rng.choice(_split(TOPIC_NOUL, held)).replace('{o}', o)
        return 'noul', [read_line(st.text, instr)], 0.98 if t == st.topic else 0.02
    if r < 0.78:                                   # choice of topic
        k = rng.randint(2, 6)
        others = [t for t in TOPIC_NAMES if t != st.topic]
        names = rng.sample(others, k - 1) + [st.topic]
        rng.shuffle(names)
        instr = rng.choice(_split(TOPIC_CHOICE, held))
        opts = [rng.choice(_split(TOPICS[t][0], held)) for t in names]
        tgt = [1.0 if t == st.topic else 0.0 for t in names]
        return 'choice', [read_line(st.text, instr, o) for o in opts], tgt
    if r < 0.90:                                   # tone as an ordered score
        instr = rng.choice(_split(TONE_CHOICE, held))
        opts = [rng.choice(_split(w, held) or w) for w in TONE_WORDS]
        tgt = [0.0, 0.0, 0.0]
        tgt[st.tone] = 1.0
        return 'score', [read_line(st.text, instr, o) for o in opts], tgt
    instr = rng.choice(_split(URG_CHOICE, held))    # urgency as an ordered score
    opts = [rng.choice(_split(w, held) or w) for w in URG_WORDS]
    if st.topic in ('praise', 'spam'):
        tgt = [0.85, 0.15, 0.0]
    elif st.urg == 1 and st.topic == 'outage':
        tgt = [0.0, 0.45, 0.55]
    else:
        tgt = [0.0, 0.0, 0.0]
        tgt[st.urg] = 1.0
    return 'score', [read_line(st.text, instr, o) for o in opts], tgt


def sample(rng, held=False, held_q=None):
    """held: message wordings never trained on.  held_q (default: same as
    held): instruction and option wordings never trained on."""
    held_q = held if held_q is None else held_q
    while True:
        st = make_state(rng, held)
        kind, lines, tgt = make_question(rng, st, held_q)
        if max(len(s) for s in lines) <= MAXLEN:
            return kind, lines, tgt


if __name__ == '__main__':
    rng = random.Random(1)
    for held in (False, True):
        print('--- held-back wordings' if held else '--- training wordings')
        for _ in range(8):
            kind, lines, tgt = sample(rng, held)
            print(kind, tgt if kind == 'noul' else [round(t, 2) for t in tgt])
            for s in lines:
                print('   ', s)
