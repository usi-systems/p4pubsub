from apptopo import AppTopo

class CustomAppTopo(AppTopo):

    def __init__(self, *args, **kwargs):
        manifest, target = kwargs['manifest'], kwargs['target']

        conf = manifest['targets'][target]

        if 'routing_conf_file' in conf:
            import json
            with open(conf['routing_conf_file'], 'r') as f:
                conf['routing_conf'] = json.load(f)

        conf['links'] = list(conf['routing_conf']['links'])
        sw_names = sorted(set(sum(map(list, conf['links']), [])))

        labels = ' '.join(["$%s_label" % sw for sw in sw_names])
        conf['hosts'] = {
                "h01": {
                    "cmd": "./label_recv.py 1234",
                    "startup_sleep": 0.9,
                    "wait": False
                },
                "h02": {
                    "cmd": "./label_send.py 255.255.255.255 1234 " + labels,
                    "wait": True
                }
            }

        for i,sw in enumerate(sw_names[:-1]):
            conf['links'].append(('h01', sw))
        conf['links'].append(('h02', sw_names[-1]))

        AppTopo.__init__(self, *args, **kwargs)

