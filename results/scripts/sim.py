#!/usr/bin/python

try:
    import psyco
    psyco.full()
except ImportError:
    pass

import pymprog

import math
import sys
import time as modtime

import bisect

import collections

# global events object
events = []

# global allocs object
allocs = set()

restart_delay = 0

jobs_transferred = 0
tasks_transferred = 0
mem_transferred = 0
jobs_restored = 0
tasks_restored = 0
mem_restored = 0

time = 0

class HostDict(dict):
    def __missing__(self, key):
        return 0

class Job:
    def __init__(self, id, subtime, tasks, cpu, mem, runtime):
        self.id = id
        self.subtime = subtime
        self.tasks = tasks
        self.cpu = int(round(100.0 * cpu))
        self.mem = int(round(100.0 * mem))
        self.runtime = runtime

        self.runmsecs = runtime * 1000

        self.usedmsecs = 0
        self.endtime = None
        self.prevalloc = None
        self.curralloc = None
        self.deadlineevent = None
        self.restart_penalty = 0
        self.rejcount = 0

        self.fsevent = None

    def __str__(self):
        return (str(self.id))

    def ftmsecs(self):
        global time
        return 1000 * (time - self.subtime)

    def vtmsecs(self):
        global time
        if self.curralloc:
            duration = max(0, 
                time - self.curralloc.starttime - self.restart_penalty)
            return self.usedmsecs + int(
                1000 * duration * self.curralloc.cpu / self.cpu)
        else:
            return self.usedmsecs

class Alloc:
    def __init__(self, job, cpu, hosts):

        self.job = job
        self.cpu = cpu
        self.hosts = hosts

        self.starttime = None
        self.endtime = None
        self.duration = 0

    def __str__(self):
        return (str(self.job.id) + "\t" + str(self.cpu) + "\t" +
            str(self.job.cpu) + "\t" + str(self.starttime) + "\t" +
            str(self.endtime) + "\t" + str(self.hosts))

def remove_event(event):
    global events
    if not event:
        return False
    eventidx = bisect.bisect(events, event) - 1
    if eventidx > -1 and events[eventidx] == event:
        del events[eventidx]
        return True
    print "ERROR: event not found:", event
    return False

def stop_alloc(alloc):
    global events
    global allocs
    global precount
    global time

    if not alloc:
        return

    job = alloc.job
    
    if alloc != job.curralloc:
        print "ERROR: stopping wrong alloc!"
        return

    job.curralloc = None

    duration = time - alloc.starttime

    if duration <= job.restart_penalty:
        job.restart_penalty -= duration
        alloc.duration = 0
    else:
        duration -= job.restart_penalty
        alloc.duration = duration
        job.restart_penalty = 0
        job.usedmsecs += int(1000 * duration * alloc.cpu / job.cpu)

    if time < alloc.endtime:
        alloc.endtime = time
        remove_event(alloc.endevent)
    else:
        alloc.job.endtime = time

    del alloc.endevent
    alloc.endevent = None

    if time == alloc.starttime:
        allocs.remove(alloc)
        del alloc
    else:
        job.prevalloc = alloc

def start_alloc(alloc):
    global events
    global allocs
    global jobs_transferred
    global tasks_transferred
    global mem_transferred
    global jobs_restored
    global tasks_restored
    global mem_restored
    global time

    job = alloc.job

    if job.fsevent:
        remove_event(job.fsevent)
        del job.fsevent
        job.fsevent = None

    if job.curralloc:
        curralloc = job.curralloc
        # do nothing if current alloc is logically the same
        if curralloc == alloc or (
            curralloc.cpu == alloc.cpu and curralloc.hosts == alloc.hosts):
            return
        stop_alloc(curralloc)

    alloc.starttime = time

    if job.prevalloc:
        prevalloc = job.prevalloc
        if prevalloc.endtime < time:
            job.restart_penalty = restart_delay
            jobs_restored += 1
            tasks_restored += sum(alloc.hosts.values())
            mem_restored += job.mem * sum(alloc.hosts.values())
        elif prevalloc.hosts != alloc.hosts:
            job.restart_penalty = restart_delay
            jobs_transferred += 1
            for host, count in prevalloc.hosts.iteritems():
                tasks_transferred += max(0, count - alloc.hosts[host])
                mem_transferred += job.mem * max(0, count - alloc.hosts[host])
        elif prevalloc.cpu == alloc.cpu:
            print "ERROR: shouldn't happen"
            return

    msecsreqd = int((job.runmsecs - job.usedmsecs) * job.cpu / alloc.cpu)
    secsreqd = int(msecsreqd / 1000)
    if msecsreqd % 1000:
        secsreqd += 1
    if secsreqd <= 0:
        print "ERROR: job", job.id, "should not have needed additional alloc!",\
            job.usedmsecs, job.runmsecs
    alloc.endtime = time + secsreqd + job.restart_penalty

    if alloc.starttime < alloc.endtime:
        allocs.add(alloc)
        job.curralloc = alloc
        alloc.endevent = (alloc.endtime, 0, job.id, alloc)
        bisect.insort(events, alloc.endevent)
    else:
        job.curralloc = None

def invpri(job):
    return ((job.vtmsecs()**2) / max(30, job.ftmsecs()), job.id)

def fcfs_sched(numhosts, argv):
    global events
    global time

    hosts = range(numhosts)
    jobs = []

    while events:

        event  = events.pop(0)
        time   = event[0]
        action = event[1]

        if action == 0: # job completes
            alloc = event[3]
            stop_alloc(alloc)
            hosts.extend(alloc.hosts.keys())
        elif action == 2: # job submitted
            job = event[3]
            jobs.append(job)
        while jobs and jobs[0].tasks <= len(hosts):
            job = jobs.pop(0)
            start_alloc(Alloc(job, job.cpu, dict.fromkeys(hosts[:job.tasks],1)))
            hosts = hosts[job.tasks:]
        
def easy_sched(numhosts, argv):
    global events
    global time

    hosts = set(range(numhosts))
    atimes = [0] * numhosts
    jobs = []
    resalloc = None
    restime = 0

    while events:

        event = events.pop(0)
        time = event[0]
        action = event[1]

        if action == 0: # alloc ends
            alloc = event[3]
            stop_alloc(alloc)
            hosts |= set(alloc.hosts.keys())
        elif action == 2: # job submitted
            jobs.append(event[3])

        if events and events[0][0] == time:
            continue

        if resalloc and restime == time:
            start_alloc(resalloc)
            hosts -= set(resalloc.hosts.keys())
            for host in resalloc.hosts:
                atimes[host] = resalloc.endtime
            resalloc = None
        elif resalloc and restime < time:
            print "ERROR: reservation not run!"

        ujobs = []

        if resalloc:
            nreshosts = hosts - set(resalloc.hosts.keys())
        else:
            nreshosts = hosts

        for job in jobs:

            if not resalloc or time + job.runtime <= resalloc.starttime:
                phosts = hosts
            else:
                phosts = nreshosts

            if job.tasks <= len(phosts):
                jhosts = set([])
                for i in range(job.tasks):
                    host = phosts.pop()
                    atimes[host] = time + job.runtime
                    hosts.discard(host)
                    nreshosts.discard(host)
                    jhosts.add(host)
                start_alloc(Alloc(job, job.cpu, dict.fromkeys(jhosts, 1)))
            elif not resalloc:
                jhosts = sorted(range(numhosts), key=(lambda x: (atimes[x], x)))
                # there are not job.tasks hosts with atimes less than current
                # time, which is at least as big as submit time
                restime = atimes[jhosts[job.tasks - 1]]
                jhosts.reverse()
                for i in range(numhosts):
                    if atimes[jhosts[i]] <= restime:
                        break
                resalloc = Alloc(job, job.cpu,
                    dict.fromkeys(jhosts[i:i + job.tasks], 1))
                nreshosts = hosts - set(resalloc.hosts.keys())
            else:
                ujobs.append(job)

        del jobs
        jobs = ujobs
                
def allocate_cpu_and_start(numhosts, cputotals, jobhosts, target):
    global time

    if not jobhosts:
        return

    minyield = float(10000 / max(100, *cputotals)) / 100

    if (target == "none"):
        for job, hosts in jobhosts.iteritems():
            start_alloc(Alloc(job, max(1, int(minyield * job.cpu)), hosts))
        return

    if (target == "maxminyield"):
        allocs = set()
        cpuloads = [0] * numhosts
        taskcounts = [0] * numhosts
        
        for job, hosts in jobhosts.iteritems():
            alloc = Alloc(job, max(1, int(minyield * job.cpu)), hosts)
            allocs.add(alloc)
            for host, count in hosts.iteritems():
                cpuloads[host] += alloc.cpu * count
                taskcounts[host] += count

        while True:

            unfilledhosts = set(x for x in range(numhosts) 
                if taskcounts[x] and (100 - cpuloads[x]) / taskcounts[x])
            improvableallocs = set(alloc for alloc in allocs 
                if alloc.cpu < alloc.job.cpu and set(host for host, count 
                    in alloc.hosts.iteritems() if count > 0) <= unfilledhosts)

            if not improvableallocs:
                break

            hosts = set()
            for alloc in improvableallocs:
                hosts |= set(host for host, count in alloc.hosts.iteritems() 
                    if count > 0)
            minamtbyhost = min((100 - cpuloads[h]) / taskcounts[h] 
                for h in hosts)
            minamtbyalloc = min(alloc.job.cpu - alloc.cpu 
                for alloc in improvableallocs)
            improveamt = min(minamtbyhost, minamtbyalloc)

            if improveamt == 0:
                print "uh oh"
                break

            for alloc in improvableallocs:
                alloc.cpu += improveamt
                for host, count in alloc.hosts.iteritems():
                    cpuloads[host] += count * improveamt

        if max(cpuloads) > 100:
            print "ERROR: invalid set of allocations at time:", time

        for alloc in allocs:
            start_alloc(alloc)

        return

    prob = pymprog.model('maximize total yield')
    cols = prob.var(jobhosts.keys(), 'alloc')

    if (target == "util"):
        prob.max(sum(cols[job] for job in jobhosts), 'total utilization')
    else:
        prob.max(sum(cols[job] / job.cpu for job in jobhosts), 'total yield')

    prob.st(max(1, int(minyield * job.cpu)) <= cols[job] <= job.cpu 
        for job in jobhosts)
    prob.st(sum(cols[job] * jobhosts[job][host] for job in jobhosts) <= 100
        for host in range(numhosts))
    prob.solve()

    cpuloads = [0] * numhosts
    for job, hosts in jobhosts.iteritems():
        alloc = Alloc(job, max(1, int(cols[job].primal)), hosts)
        start_alloc(alloc)
        for host, count in hosts.iteritems():
            cpuloads[host] += alloc.cpu * count

    if max(cpuloads) > 100:
        print "ERROR: invalid set of allocations at time:", time

    return

def mcb8(numhosts, allocs):
    callocs = []
    mallocs = []
    cpuloads = [0] * numhosts
    memtotals = [0] * numhosts

    for alloc in allocs:
        if alloc.hosts:
            for host, count in alloc.hosts.iteritems():
                cpuloads[host] += alloc.cpu * count
                memtotals[host] += alloc.job.mem * count
        else:
            alloc.hosts = HostDict()
            if alloc.cpu > alloc.job.mem:
                callocs.append(alloc)
            else:
                mallocs.append(alloc)

    if max(cpuloads) > 100:
        return False

    callocs.sort(key=(lambda x: (x.cpu, x.job.mem, x.job.id)), reverse=True)
    mallocs.sort(key=(lambda x: (x.job.mem, x.cpu, x.job.id)), reverse=True)

    for host in xrange(numhosts):

        if not callocs and not mallocs:
            break

        idxs = [0, 0]

        while idxs[0] < len(callocs) or idxs[1] < len(mallocs):
            if ((cpuloads[host] <= memtotals[host] and idxs[0] < len(callocs))
                or idxs[1] >= len(mallocs)):
                tallocs = callocs
                idxtype = 0
            else:
                tallocs = mallocs
                idxtype = 1

            idx = idxs[idxtype]

            while idx < len(tallocs):
                alloc = tallocs[idx]
                if (cpuloads[host] + alloc.cpu <= 100 and
                    memtotals[host] + alloc.job.mem <= 100):
                    cpuloads[host] += alloc.cpu
                    memtotals[host] += alloc.job.mem
                    alloc.hosts[host] += 1
                    if sum(alloc.hosts.values()) == alloc.job.tasks:
                        del tallocs[idx]
                    break
                else:
                    idx += 1
            
            idxs[idxtype] = idx

    if callocs or mallocs:
        return False

    return True

def schedule_jobs_bs(numhosts, jobs, jobhosts):
    global time
    runjobs = jobs.copy()
    fjobhosts = {}

    memtotal = 0
    for job in runjobs:
        memtotal += job.mem * job.tasks

    # keeps us from doing a binary search until there is enough
    # memory for an at least theoretical solution...
    while memtotal > (numhosts * 100):
        stopjob = max(runjobs, key=invpri)
        memtotal -= stopjob.mem * stopjob.tasks
        runjobs.remove(stopjob)

    while runjobs:

        minyieldlb = 0.0
        minyieldub = 1.0

        while minyieldub - minyieldlb > 0.01:
            minyield = (minyieldub + minyieldlb) / 2.0
            allocs = set()
            for job in runjobs:
                if job in jobhosts:
                    hosts = jobhosts[job]
                else:
                    hosts = None
                allocs.add(Alloc(job, max(1, int(minyield * job.cpu)), hosts))

            if mcb8(numhosts, allocs):
                fjobhosts = dict((alloc.job, alloc.hosts) for alloc in allocs)
                minyieldlb = minyield
            else:
                del allocs
# FIXME: why not just stop if you fail after succeeding?
                if fjobhosts:
                    break
                minyieldub = minyield

        if fjobhosts:
            break

        runjobs.remove(max(runjobs, key=invpri))

    return fjobhosts

def add_job(job, hosts, cputotals, memtotals):
    for host, count in hosts.iteritems():
        cputotals[host] += job.cpu * count
        memtotals[host] += job.mem * count

def remove_job(job, hosts, cputotals, memtotals):
    for host, count in hosts.iteritems():
        cputotals[host] -= job.cpu * count
        memtotals[host] -= job.mem * count

def schedule_job_greedy(numhosts, cputotals, memtotals, job):
    hosts = HostDict()
    phosts = set(h for h in range(numhosts) if memtotals[h] + job.mem <= 100)
    while phosts and sum(hosts.values()) < job.tasks:
        host = min(phosts, key=(lambda h: (cputotals[h], h)))
        hosts[host] += 1
        cputotals[host] += job.cpu
        memtotals[host] += job.mem
        if memtotals[host] + job.mem > 100:
            phosts.remove(host)

    if sum(hosts.values()) < job.tasks:
        remove_job(job, hosts, cputotals, memtotals)
        return None

    return hosts


def schedule_job_greedy_pmtn(numhosts, cputotals, memtotals, jobhosts, job,
    pjobs):
    hosts = None

    while True:
        hosts = schedule_job_greedy(numhosts, cputotals, memtotals, job)
        if hosts:
            break
        pjob = max(set(jobhosts.keys()) - pjobs, key=invpri)
        pjobs.add(pjob)
        remove_job(pjob, jobhosts[pjob], cputotals, memtotals)
    for pjob in sorted(pjobs, key=invpri):
        canfit = True
        for host, count in jobhosts[pjob].iteritems():
            if memtotals[host] + pjob.mem * count > 100:
                canfit = False
                break
        if canfit:
            pjobs.remove(pjob)
            add_job(pjob, jobhosts[pjob], cputotals, memtotals)

    return hosts

def smart_sched(numhosts, argv):
    global events
    global time

    jobs = set()
    jobhosts = {}
    cputotals = [0] * numhosts
    memtotals = [0] * numhosts

    onsubmit = False
    pmtn = False
    mig = False
    pdelay = 0

    activeres = False

    periodic = False
    period = 0
    minvt = 0
    minft = 0
    nomcbmigr = False

    target = "avgyield"

    for word in argv:
        if word.startswith("greedy"):
            onsubmit = True
            suffix = word[6:]
            if suffix.startswith("-pmtn"):
                pmtn = True
                if suffix.endswith("-migr"):
                    mig = True
        elif word.startswith("pdelay:"):
            pdelay = int(word[7:])
        elif word == "activeres":
            activeres = True
        elif word.startswith("per:"):
            periodic = True
            period = int(word[4:])
        elif word.startswith("minvt:"):
            minvt = int(word[6:])
        elif word.startswith("minft:"):
            minft = int(word[6:])
        elif word == "nomcbmigr":
            nomcbmigr = True
        elif word.startswith("opttarget:"):
            target = word[10:]
    
    if not onsubmit and not periodic:
        print "ERROR: one of onsubmit or periodic must be true!"
        return

    if not activeres and not periodic:
        print "ERROR: one of activeres or periodic must be true!"
        return

    next_per_mcb8_time = 0
    if periodic:
        bisect.insort(events, (0, 3))

    pjobs = set()

    while events:

        event = events.pop(0)
        time = event[0]
        action = event[1]
        
        if action == 0:
            alloc = event[3]
            job = alloc.job
            stop_alloc(alloc)
            jobs.remove(job)
            remove_job(job, alloc.hosts, cputotals, memtotals)
            del jobhosts[job]
        elif action == 1:
            job = event[3]
            del job.fsevent
            job.fsevent = None
            jobhosts[job] = schedule_job_greedy_pmtn(numhosts, cputotals,
                memtotals, jobhosts, job, pjobs)
        elif action == 2:
            job = event[3]
            jobs.add(job)
            if onsubmit and time != next_per_mcb8_time:
                if pmtn and pdelay == 0:
                    jobhosts[job] = schedule_job_greedy_pmtn(numhosts, 
                        cputotals, memtotals, jobhosts, job, pjobs)
                else:
                    hosts = schedule_job_greedy(numhosts, cputotals, memtotals,
                        job)
                    if hosts:
                        jobhosts[job] = hosts
                    elif pmtn and time + pdelay < next_per_mcb8_time:
                        job.fsevent = (time + pdelay, 1, job.id, job)
                        bisect.insort(events, job.fsevent)
        elif action == 3 and (jobs or events):
            next_per_mcb8_time = time + period
            bisect.insort(events, (next_per_mcb8_time, 3))
            if jobs:
                if minvt > 0:
                    jobhosts = dict((job, hosts)
                            for job, hosts in jobhosts.iteritems()
                            if job.vtmsecs() < 1000 * minvt)
                elif minft > 0:
                    jobhosts = dict((job, hosts)
                            for job, hosts in jobhosts.iteritems()
                            if job.ftmsecs() < 1000 * minft)
                elif not nomcbmigr:
                    jobhosts = dict()
                jobhosts = schedule_jobs_bs(numhosts, jobs, jobhosts)
                cputotals = [0] * numhosts
                memtotals = [0] * numhosts
                for job, hosts in jobhosts.iteritems():
                    add_job(job, hosts, cputotals, memtotals)

        if events and time == events[0][0]:
            continue

        if mig:
            for job in sorted(pjobs, key=invpri):
                hosts = schedule_job_greedy(numhosts, cputotals, memtotals, job)
                if hosts:
                    pjobs.remove(job)
                    jobhosts[job] = hosts

        if activeres:
            for job in sorted(jobs - set(jobhosts.keys()), key=invpri):
                hosts = schedule_job_greedy(numhosts, cputotals, memtotals, job)
                if hosts:
                    jobhosts[job] = hosts

        for job in pjobs:
            del jobhosts[job]
        pjobs.clear()

        for job in jobs - set(jobhosts.keys()):
            if job.curralloc:
                stop_alloc(job.curralloc)

        allocate_cpu_and_start(numhosts, cputotals, jobhosts, target)

    for job in jobs:
        print "ERROR: job still in queue", job.id, job.usedmsecs, job.runmsecs

    return

def mcb8_sched(numhosts, argv):
    global events
    global time

    jobs = set()
    jobhosts = {}

    periodic = False
    period = 0
    minvt = 0
    minft = 0
    nomcbmigr = False

    target = "avgyield"

    for word in argv:
        if word.startswith("per:"):
            periodic = True
            period = int(word[4:])
        elif word.startswith("minvt:"):
            minvt = int(word[6:])
        elif word.startswith("minft:"):
            minft = int(word[6:])
        elif word == "nomcbmigr":
            nomcbmigr = True
        elif word.startswith("opttarget:"):
            target = word[10:]
    
    if periodic:
        bisect.insort(events, (0, 3))

    while events:

        event = events.pop(0)
        time = event[0]
        action = event[1]
        
        if action == 0:
            alloc = event[3]
            job = alloc.job
            stop_alloc(alloc)
            jobs.remove(job)
        elif action == 2:
            job = event[3]
            jobs.add(job)
        elif action == 3 and (jobs or events):
            bisect.insort(events, (time + period, 3))

        if events and time == events[0][0]:
            continue

        if jobs:

            if minvt > 0:
                jobhosts = dict((job, hosts)
                        for job, hosts in jobhosts.iteritems()
                        if job.vtmsecs() < 1000 * minvt)
            elif minft > 0:
                jobhosts = dict((job, hosts)
                        for job, hosts in jobhosts.iteritems()
                        if job.ftmsecs() < 1000 * minft)
            elif not nomcbmigr:
                jobhosts = dict()

            jobhosts = schedule_jobs_bs(numhosts, jobs, jobhosts)

            cputotals = [0] * numhosts
            memtotals = [0] * numhosts
            for job, hosts in jobhosts.iteritems():
                add_job(job, hosts, cputotals, memtotals)

            for job in jobs - set(jobhosts.keys()):
                if job.curralloc:
                    stop_alloc(job.curralloc)

            allocate_cpu_and_start(numhosts, cputotals, jobhosts, target)

    for job in jobs:
        print "ERROR: job still in queue", job.id, job.usedmsecs, job.runmsecs

    return

def allocate_cpu_and_start_stretch(numhosts, cputotals, jobhosts, jobcpus,
    next_per_mcb8_time):
    global time

    if not jobhosts:
        return

    prob = pymprog.model('maximize total avg yield')
    cols = prob.var(jobhosts.keys(), 'alloc')
    prob.max(sum((job.vtmsecs() + cols[job] * (next_per_mcb8_time - time)) / 
    (job.ftmsecs() + next_per_mcb8_time - time) for job in jobhosts),
        'total time weighted average yield')
    prob.st(jobcpus[job] <= cols[job] <= job.cpu for job in jobhosts)
    prob.st(sum(cols[job] * jobhosts[job][host] for job in jobhosts) <= 100
        for host in range(numhosts))
    prob.solve()

    cpuloads = [0] * numhosts
    for job, hosts in jobhosts.iteritems():
        alloc = Alloc(job, max(1, int(cols[job].primal)), hosts)
        start_alloc(alloc)
        for host, count in hosts.iteritems():
            cpuloads[host] += alloc.cpu * count

    if max(cpuloads) > 100:
        print "ERROR: invalid set of allocations at time:", time

    return

def schedule_jobs_bs_stretch(numhosts, jobs, jobhosts, period):
    global time
    runjobs = jobs.copy()
    fminavgyield = None
    fjobcpus = {}
    fjobhosts = {}

    memtotal = 0
    for job in runjobs:
        memtotal += job.mem * job.tasks

    # keeps us from doing a binary search until there is enough
    # memory for an at least theoretical solution...
    while memtotal > (numhosts * 100):
        stopjob = max(runjobs, key=invpri)
        memtotal -= stopjob.mem * stopjob.tasks
        runjobs.remove(stopjob)

    while runjobs:

        minavgyieldlb = 0.0
        minavgyieldub = 1.0

        while minavgyieldub - minavgyieldlb > 0.01:
            minavgyield = (minavgyieldub + minavgyieldlb) / 2.0
            allocs = set()
            for job in runjobs:
                if job in jobhosts:
                    hosts = jobhosts[job]
                else:
                    hosts = None
                allocs.add(Alloc(job, max(1, min(job.cpu, int(job.cpu *
                    float(minavgyield *
                    (job.ftmsecs() + 1000 * period) - job.vtmsecs()) / 
                    (1000 * period)))), hosts))

            if mcb8(numhosts, allocs):
                fminavgyield = minavgyield
                fjobcpus = dict((alloc.job, alloc.cpu) for alloc in allocs)
                fjobhosts = dict((alloc.job, alloc.hosts) for alloc in allocs)
                minavgyieldlb = minavgyield
            else:
                del allocs
                minavgyieldub = minavgyield

        if fjobcpus and fjobhosts:
            break

        runjobs.remove(max(runjobs, key=invpri))

    return fjobcpus, fjobhosts

def schedule_jobs_bs_stretch2(numhosts, jobs, jobhosts, period):
    global time
    pmsecs = 1000 * period
    runjobs = jobs.copy()
    fminavgyield = None
    fjobcpus = {}
    fjobhosts = {}

    memtotal = 0
    for job in runjobs:
        memtotal += job.mem * job.tasks

    # keeps us from doing a binary search until there is enough
    # memory for an at least theoretical solution...
    while memtotal > (numhosts * 100):
        stopjob = max(runjobs, key=invpri)
        memtotal -= stopjob.mem * stopjob.tasks
        runjobs.remove(stopjob)

    while runjobs:

        minavgyieldlb = 0.0
        minavgyieldub = 1.0

        while minavgyieldub - minavgyieldlb > 0.0001:
            minavgyield = (minavgyieldub + minavgyieldlb) / 2.0
            allocs = set()
            maxjobyield = 0.0
            for job in runjobs:
                if job in jobhosts:
                    hosts = jobhosts[job]
                else:
                    hosts = None
                jobyield = (minavgyield * 
                    (job.ftmsecs() + pmsecs) - job.vtmsecs()) / pmsecs
                maxjobyield = max(maxjobyield, jobyield)
                if maxjobyield > 1.0:
                    break
                allocs.add(Alloc(job, max(1, int(jobyield * job.cpu)), hosts))

            if maxjobyield <= 1.0 and mcb8(numhosts, allocs):
                fminavgyield = minavgyield
                fjobcpus = dict((alloc.job, alloc.cpu) for alloc in allocs)
                fjobhosts = dict((alloc.job, alloc.hosts) for alloc in allocs)
                minavgyieldlb = minavgyield
            else:
                del allocs
                minavgyieldub = minavgyield

        if fjobcpus and fjobhosts:
            break

        runjobs.remove(max(runjobs, key=invpri))

    return fjobcpus, fjobhosts

def stretch_sched(numhosts, argv):
    global events
    global time

    jobs = set()
    jobcpus = {}
    jobhosts = {}
    cputotals = [0] * numhosts
    memtotals = [0] * numhosts

    periodic = False
    period = 0
    minvt = 0
    minft = 0

    for word in argv:
        if word.startswith("per:"):
            periodic = True
            period = int(word[4:])
        elif word.startswith("minvt:"):
            minvt = int(word[6:])
        elif word.startswith("minft:"):
            minft = int(word[6:])
    
    if not periodic:
        print "ERROR: strech sched must be periodic!"
        return

    next_per_mcb8_time = 0
    if periodic:
        bisect.insort(events, (0, 3))

    pjobs = set()

    while events:

        event = events.pop(0)
        time = event[0]
        action = event[1]
        
        if action == 0:
            alloc = event[3]
            job = alloc.job
            stop_alloc(alloc)
            jobs.remove(job)
            del jobcpus[job]
            del jobhosts[job]
        elif action == 2:
            job = event[3]
            jobs.add(job)
        elif action == 3 and (jobs or events):
            next_per_mcb8_time = time + period
            bisect.insort(events, (next_per_mcb8_time, 3))
            if jobs:
                if minvt > 0:
                    jobhosts = dict((job, hosts)
                            for job, hosts in jobhosts.iteritems()
                            if job.vtmsecs() < 1000 * minvt)
                elif minft > 0:
                    jobhosts = dict((job, hosts)
                            for job, hosts in jobhosts.iteritems()
                            if job.ftmsecs() < 1000 * minft)
                else:
                    jobhosts = dict()
                jobcpus, jobhosts = schedule_jobs_bs_stretch(numhosts, jobs,
                    jobhosts, period)
                cputotals = [0] * numhosts
                memtotals = [0] * numhosts
                for job, hosts in jobhosts.iteritems():
                    add_job(job, hosts, cputotals, memtotals)

        if events and time == events[0][0]:
            continue

        for job in jobs - set(jobhosts.keys()):
            if job.curralloc:
                stop_alloc(job.curralloc)

        allocate_cpu_and_start_stretch(numhosts, cputotals, jobhosts, jobcpus,
            next_per_mcb8_time)

    for job in jobs:
        print "ERROR: job still in queue", job.id, job.usedmsecs, job.runmsecs

    return

def stretch2_sched(numhosts, argv):
    global events
    global time

    jobs = set()
    jobcpus = {}
    jobhosts = {}
    cputotals = [0] * numhosts
    memtotals = [0] * numhosts

    periodic = False
    period = 0
    minvt = 0
    minft = 0

    for word in argv:
        if word.startswith("per:"):
            periodic = True
            period = int(word[4:])
        elif word.startswith("minvt:"):
            minvt = int(word[6:])
        elif word.startswith("minft:"):
            minft = int(word[6:])
    
    if not periodic:
        print "ERROR: strech sched must be periodic!"
        return

    next_per_mcb8_time = 0
    if periodic:
        bisect.insort(events, (0, 3))

    pjobs = set()

    while events:

        event = events.pop(0)
        time = event[0]
        action = event[1]
        
        if action == 0:
            alloc = event[3]
            job = alloc.job
            stop_alloc(alloc)
            jobs.remove(job)
            del jobcpus[job]
            del jobhosts[job]
        elif action == 2:
            job = event[3]
            jobs.add(job)
        elif action == 3 and (jobs or events):
            next_per_mcb8_time = time + period
            bisect.insort(events, (next_per_mcb8_time, 3))
            if jobs:
                if minvt > 0:
                    jobhosts = dict((job, hosts)
                            for job, hosts in jobhosts.iteritems()
                            if job.vtmsecs() < 1000 * minvt)
                elif minft > 0:
                    jobhosts = dict((job, hosts)
                            for job, hosts in jobhosts.iteritems()
                            if job.ftmsecs() < 1000 * minft)
                else:
                    jobhosts = dict()
                jobcpus, jobhosts = schedule_jobs_bs_stretch2(numhosts, jobs,
                    jobhosts, period)
                cputotals = [0] * numhosts
                memtotals = [0] * numhosts
                for job, hosts in jobhosts.iteritems():
                    add_job(job, hosts, cputotals, memtotals)

        if events and time == events[0][0]:
            continue

        for job in jobs - set(jobhosts.keys()):
            if job.curralloc:
                stop_alloc(job.curralloc)

        allocate_cpu_and_start_stretch(numhosts, cputotals, jobhosts, jobcpus,
            next_per_mcb8_time)

    for job in jobs:
        print "ERROR: job still in queue", job.id, job.usedmsecs, job.runmsecs

    return
def checkallocs(numhosts, allocs, completed_jobs):
    events = []
    cputotals = [0] * numhosts
    memtotals = [0] * numhosts
    maxcpu = 0
    maxmem = 0

    for job in completed_jobs:
        job.lastallocend = 0
        job.msecsreqd = 1000 * job.runtime

    allocs.sort(key=(lambda x: (x.starttime, x.endtime, x.job.id)))
    for alloc in allocs:
        if alloc.starttime < alloc.job.lastallocend:
            print "ERROR: job", alloc.job.id, "has overlapping allocs!"
        alloc.job.lastallocend = alloc.endtime
        if alloc.cpu > alloc.job.cpu:
            print "ERROR: alloc for job", alloc.job.id, "starting at",\
                alloc.starttime, "has excessive alloc."
        if sum(alloc.hosts.values()) != alloc.job.tasks:
            print "ERROR: alloc for job", alloc.job.id, "starting at",\
                    alloc.starttime, "has wrong number of hosts:",\
                    alloc.job.tasks, sum(alloc.hosts.values())
        events.append((alloc.endtime, 0, alloc))
        events.append((alloc.starttime, 1, alloc))
        alloc.job.msecsreqd -= int(1000 * alloc.duration * alloc.cpu /
            alloc.job.cpu)

    events.sort()

    totproctime = 0
    totcputime = 0.0
    tottime = 0
    currtime = events[0][0]

    for event in events:
        time = event[0]
        alloc = event[2]

        timespan = time - currtime
        currtime = time

        activehosts = sum(1 for h in range(numhosts) if cputotals[h] > 0)
        totproctime += timespan * activehosts
        totcputime += timespan * sum(cputotals)
        tottime += timespan

        if event[1] == 0:
            for host, count in alloc.hosts.iteritems():
                cputotals[host] = max(0, cputotals[host] - alloc.cpu * count)
                memtotals[host] = max(0, memtotals[host] - 
                    alloc.job.mem * count)
        else:
            for host, count in alloc.hosts.iteritems():
                cputotals[host] += alloc.cpu * count
                memtotals[host] += alloc.job.mem * count
                if cputotals[host] > 100:
                    print "ERROR: alloc for job", alloc.job.id, "starting at", \
                        alloc.starttime, "and ending at", alloc.endtime, \
                        "pushed host", host,"to cpu total", \
                        cputotals[host], "with allocation of", alloc.cpu, "."
                if cputotals[host] > maxcpu:
                    maxcpu = cputotals[host]
            
                if memtotals[host] > 100:
                    print "ERROR: alloc for job ", alloc.job.id, "starting at",\
                        alloc.starttime, "pushed host", host, \
                        "to mem total", memtotals[host], "."
                if memtotals[host] > maxmem:
                    maxmem = memtotals[host]

    for job in completed_jobs:
        if job.msecsreqd > 0:
            print "ERROR: job", job.id, "still needs", job.msecsreqd, "msecs."
        elif job.msecsreqd < -999:
            print "ERROR: job", job.id, "overran for", -job.msecsreqd, "msecs."

    return (float(totproctime) / (tottime * numhosts),
        totcputime / (tottime * numhosts) / 100.0)

#### START OF PROGRAM EXECUTION ####

numhosts = int(sys.argv[1])
restart_delay = int(sys.argv[2])
scheduler = sys.argv[3]

# events are tuples instead of classes because it makes sorting easy,
# type 0 events are allocation end events, type 1 events are allocation
# start events, and type 2 events are job submit events.  Thus, jobs are
# always removed from the system before new jobs are started, which is done
# before even newer jobs are scheduled.

events.extend([(lambda x: (int(x[1]), 2, int(x[0]),
    Job(int(x[0]), int(x[1]), int(x[2]), float(x[3]), float(x[4]), int(x[5]))))
    (line.split()) for line in sys.stdin if not line.lstrip().startswith(";")])
jobs = [event[3] for event in events]

events.sort()

schedulers = {
    "fcfs": fcfs_sched,
    "easy": easy_sched,
    "smart": smart_sched,
    "mcb8": mcb8_sched,
    "stretch": stretch_sched,
    "stretch2": stretch2_sched
}

schedfunc = schedulers[scheduler]

if schedfunc:
    starttime = modtime.time()
    schedfunc(numhosts, sys.argv[4:])
    endtime = modtime.time()
    comptime = max(0, int(endtime - starttime))
else:
    print "scheduler \"%s\" not defined!" % (scheduler)
    
runthresh = 30
stretches = [
    max(1.0, float(job.endtime - job.subtime) / max(runthresh, job.runtime))
    for job in jobs]
starttime = min(job.subtime for job in jobs)
endtime = max(job.endtime for job in jobs)
tottime = endtime - starttime
procutil, cpuutil = checkallocs(numhosts, list(allocs), jobs)
print min(stretches), "\t",\
      sum(stretches) / len(stretches), "\t",\
      max(stretches), "\t",\
      tottime, "\t",\
      procutil, "\t",\
      cpuutil, "\t",\
      len(allocs), "\t",\
      comptime, "\t",\
      jobs_restored, "\t",\
      tasks_restored, "\t",\
      mem_restored, "\t",\
      jobs_transferred, "\t",\
      tasks_transferred, "\t",\
      mem_transferred
#jobstretches = dict(
#    (job, 
#        max(1.0, float(job.endtime - job.subtime) / max(runthresh, job.runtime))
#    ) for job in jobs)
#jobs.sort(key=(lambda job: jobstretches[job]), reverse=True)
#for job in jobs:
#    print job.id, jobstretches[job]
#for alloc in sorted(allocs,
#    key=(lambda x: (x.starttime, x.endtime, x.job.id))):
#    print alloc
